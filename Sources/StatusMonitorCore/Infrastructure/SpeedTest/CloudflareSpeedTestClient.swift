import Darwin
import Foundation

/**
 Runs the internet speed test against Cloudflare's speed endpoints.

 The run measures latency first, then download, then upload. Each throughput phase runs parallel streams for a warm-up
 and a measured window. Rates are decimal Mbit/s. Packet loss is not measured in this phase, so it is always nil.
 Nothing is sent back to the service: the client only downloads and uploads test payloads.
 */
public struct CloudflareSpeedTestClient: SpeedTestPort {
    /// The service the test measures against. Change this one constant to point the test somewhere else.
    public static let defaultBaseURL = URL(string: "https://speed.cloudflare.com")!

    /**
     The path for latency and download requests. Latency asks for zero bytes, and each download asks for
     `Tuning.downloadRequestBytes`.
     */
    static let downloadPath = "__down"

    /// The path for upload requests. Each upload is a POST of `Tuning.uploadBodyBytes` bytes.
    static let uploadPath = "__up"

    /**
     Maps an HTTP status to the speed test failure it causes.

     - Parameter statusCode: The status code of the response.
     - Returns: Nil for 200 through 299. `rateLimited` for 429. `serviceUnavailable` for any other status.
     */
    static func failure(forStatusCode statusCode: Int) -> SpeedTestError? {
        switch statusCode {
        case 200...299:
            return nil
        case 429:
            return .rateLimited
        default:
            return .serviceUnavailable
        }
    }

    /// Sizes, counts and timings for a run. The standard values follow the speed test spec.
    struct Tuning {
        var parallelStreams = 6
        var downloadRequestBytes: Int64 = 25_000_000
        var uploadBodyBytes = 8_000_000
        var downloadCap: Int64 = 200_000_000
        var uploadCap: Int64 = 50_000_000
        var latencyRequests = 20
        var warmUpCeiling: TimeInterval = 3
        var measuredDuration: TimeInterval = 10
        var sampleInterval: TimeInterval = 0.25
        var uploadCountingDelay: TimeInterval = 1

        static let standard = Tuning()
    }

    private let baseURL: URL
    private let makeConfiguration: () -> URLSessionConfiguration
    private let clock: () -> TimeInterval
    private let tuning: Tuning

    /**
     Creates a client.

     - Parameters:
       - baseURL: The service to measure against. Defaults to `defaultBaseURL`.
       - makeConfiguration: Supplies a fresh base configuration for each session. Defaults to an ephemeral one.
       - clock: Returns monotonic seconds. Defaults to the system's monotonic clock.
     */
    public init(
        baseURL: URL = CloudflareSpeedTestClient.defaultBaseURL,
        makeConfiguration: @escaping () -> URLSessionConfiguration = { URLSessionConfiguration.ephemeral },
        clock: @escaping () -> TimeInterval = CloudflareSpeedTestClient.systemClock
    ) {
        self.init(baseURL: baseURL, makeConfiguration: makeConfiguration, clock: clock, tuning: .standard)
    }

    init(
        baseURL: URL,
        makeConfiguration: @escaping () -> URLSessionConfiguration,
        clock: @escaping () -> TimeInterval,
        tuning: Tuning
    ) {
        self.baseURL = baseURL
        self.makeConfiguration = makeConfiguration
        self.clock = clock
        self.tuning = tuning
    }

    /**
     Returns monotonic seconds from the system clock.

     - Returns: Seconds since an arbitrary fixed point. Only differences are meaningful.
     */
    public static func systemClock() -> TimeInterval {
        Double(SystemMonotonicClock().nanoseconds()) / 1_000_000_000
    }

    /**
     Runs one speed test from start to finish.

     - Parameter progress: Receives updates as each phase starts and as rates are measured. It may run on any thread,
       so it should hand work off rather than block.
     - Returns: The measured result. Phases that were not measured are nil.
     - Throws: `SpeedTestError`. Throws `SpeedTestError.cancelled` when the task is cancelled.
     */
    public func run(progress: @escaping (SpeedTestProgress) -> Void) async throws -> SpeedTestResult {
        do {
            progress(.latency)
            let latency = try await makeLatencyProbe().measure()
            let downloadMbps = try await measureDownload(progress: progress)
            let uploadMbps = try await measureUpload(progress: progress)
            try Task.checkCancellation()
            return SpeedTestResult(
                downloadMbps: downloadMbps,
                uploadMbps: uploadMbps,
                latencyMs: latency?.medianMs,
                jitterMs: latency?.jitterMs,
                packetLossPercent: nil,
                measuredAt: Date()
            )
        } catch is CancellationError {
            throw SpeedTestError.cancelled
        }
    }

    private var downloadURL: URL {
        endpoint(Self.downloadPath, query: [URLQueryItem(name: "bytes", value: String(tuning.downloadRequestBytes))])
    }

    private var uploadURL: URL {
        endpoint(Self.uploadPath)
    }

    private func endpoint(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = "/" + path
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? baseURL
    }

    private func makeLatencyProbe() -> SpeedTestLatencyProbe {
        SpeedTestLatencyProbe(
            url: endpoint(Self.downloadPath, query: [URLQueryItem(name: "bytes", value: "0")]),
            makeConfiguration: makeConfiguration,
            requestCount: tuning.latencyRequests
        )
    }

    private func makeWindow(dataCap: Int64) -> SpeedTestWindow {
        SpeedTestWindow(
            warmUpCeiling: tuning.warmUpCeiling,
            sampleInterval: tuning.sampleInterval,
            measuredDuration: tuning.measuredDuration,
            dataCap: dataCap
        )
    }

    private func measureDownload(progress: @escaping (SpeedTestProgress) -> Void) async throws -> Double? {
        let url = downloadURL
        let expectedBytes = tuning.downloadRequestBytes
        let streams = (0..<tuning.parallelStreams).map { _ in
            SpeedTestStream(
                kind: .download(url: url, expectedBytes: expectedBytes),
                configuration: makeConfiguration(),
                clock: clock,
                uploadCountingDelay: 0
            )
        }
        let outcome = try await measurePhase(
            streams: streams,
            window: makeWindow(dataCap: tuning.downloadCap),
            progress: { progress(.download($0)) }
        )
        return outcome.mbps
    }

    private func measureUpload(progress: @escaping (SpeedTestProgress) -> Void) async throws -> Double? {
        let url = uploadURL
        let body = Self.randomBuffer(count: tuning.uploadBodyBytes)
        let streams = (0..<tuning.parallelStreams).map { _ in
            SpeedTestStream(
                kind: .upload(url: url, body: body),
                configuration: makeConfiguration(),
                clock: clock,
                uploadCountingDelay: tuning.uploadCountingDelay
            )
        }
        let outcome = try await measurePhase(
            streams: streams,
            window: makeWindow(dataCap: tuning.uploadCap),
            progress: { progress(.upload($0)) }
        )
        return outcome.mbps
    }

    /// Runs the streams and a monitor together. The first finished monitor ends the phase and cancels the streams.
    private func measurePhase(
        streams: [SpeedTestStream],
        window: SpeedTestWindow,
        progress: @escaping (Double) -> Void
    ) async throws -> SpeedTestWindow.Outcome {
        let clock = self.clock
        let sampleInterval = tuning.sampleInterval
        return try await withThrowingTaskGroup(of: SpeedTestWindow.Outcome?.self) { group in
            for stream in streams {
                group.addTask {
                    try await stream.run()
                    return nil
                }
            }
            group.addTask {
                try await Self.monitor(
                    streams: streams,
                    window: window,
                    clock: clock,
                    sampleInterval: sampleInterval,
                    progress: progress
                )
            }
            var outcome: SpeedTestWindow.Outcome?
            for try await value in group {
                if let value {
                    outcome = value
                    group.cancelAll()
                }
            }
            guard let outcome else { throw SpeedTestError.serviceUnavailable }
            return outcome
        }
    }

    /// Samples the streams' byte totals on each tick until the window ends. Throws when every stream has failed.
    private static func monitor(
        streams: [SpeedTestStream],
        window initial: SpeedTestWindow,
        clock: @escaping () -> TimeInterval,
        sampleInterval: TimeInterval,
        progress: @escaping (Double) -> Void
    ) async throws -> SpeedTestWindow.Outcome {
        var window = initial
        _ = window.update(totalBytes: countedBytes(streams), now: clock())
        while true {
            try await Task.sleep(nanoseconds: UInt64(sampleInterval * 1_000_000_000))
            if let rate = window.update(totalBytes: countedBytes(streams), now: clock()) {
                progress(rate)
            }
            if streams.allSatisfy({ $0.failure != nil }), let failure = streams.compactMap(\.failure).first {
                throw failure
            }
            if let outcome = window.outcome {
                return outcome
            }
        }
    }

    private static func countedBytes(_ streams: [SpeedTestStream]) -> Int64 {
        streams.reduce(0) { $0 + $1.countedBytes }
    }

    /// Fills a buffer with random bytes, so the upload is not compressible.
    private static func randomBuffer(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            if let base = buffer.baseAddress {
                arc4random_buf(base, buffer.count)
            }
        }
        return data
    }
}
