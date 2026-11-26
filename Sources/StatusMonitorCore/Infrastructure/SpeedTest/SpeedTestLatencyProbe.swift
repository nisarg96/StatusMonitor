import Foundation

/**
 Measures round-trip latency with small requests sent on one session.

 Only samples on a reused connection are kept, because a new connection includes the handshake. Each kept round trip
 is the time from request start to response start, less the server's own `cfRequestDuration` when it is reported.
 */
struct SpeedTestLatencyProbe {
    /// One probe request, as read from its transaction metrics.
    struct Observation: Equatable {
        /// Time from request start to response start, in milliseconds.
        let roundTripMs: Double
        /// The server's processing time from its Server-Timing header, in milliseconds. Nil when not reported.
        let serverTimingMs: Double?
        /// Whether the request reused a connection from an earlier request.
        let isReusedConnection: Bool
    }

    /// The latency summary over the kept samples.
    struct Measurement: Equatable {
        /// The median latency in milliseconds.
        let medianMs: Double
        /// The mean absolute difference between neighbouring samples, in milliseconds. Nil with fewer than two samples.
        let jitterMs: Double?
    }

    private let url: URL
    private let makeConfiguration: () -> URLSessionConfiguration
    private let requestCount: Int

    /**
     Creates a probe.

     - Parameters:
       - url: The URL each probe request fetches. It should return an empty body.
       - makeConfiguration: Supplies the configuration for the probe's session.
       - requestCount: How many requests to send.
     */
    init(url: URL, makeConfiguration: @escaping () -> URLSessionConfiguration, requestCount: Int) {
        self.url = url
        self.makeConfiguration = makeConfiguration
        self.requestCount = requestCount
    }

    /**
     Keeps the reused-connection samples and summarizes them.

     - Parameter observations: Every probe observation, in the order the requests were sent.
     - Returns: The median and jitter of the kept samples, or nil when no sample was kept.
     */
    static func summarize(_ observations: [Observation]) -> Measurement? {
        let latencies = observations.filter(\.isReusedConnection).map {
            SpeedTestMath.latencyFromServerTiming(roundTripMs: $0.roundTripMs, serverTimingMs: $0.serverTimingMs)
        }
        guard let median = SpeedTestMath.median(latencies) else { return nil }
        return Measurement(medianMs: median, jitterMs: SpeedTestMath.jitter(latencies))
    }

    /**
     Reads the `cfRequestDuration` value from a Server-Timing header.

     - Parameter header: The raw Server-Timing header value, or nil when the response has none.
     - Returns: The duration in milliseconds, or nil when the header has no `cfRequestDuration` entry with a `dur`
       value.
     */
    static func serverTimingMs(fromHeader header: String?) -> Double? {
        guard let header else { return nil }
        for metric in header.split(separator: ",") {
            let parts = metric.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.first == "cfRequestDuration" else { continue }
            for parameter in parts.dropFirst() where parameter.hasPrefix("dur=") {
                return Double(parameter.dropFirst(4))
            }
        }
        return nil
    }

    /**
     Sends the probe requests one at a time and summarizes them.

     - Returns: The latency summary, or nil when no sample used a reused connection.
     - Throws: `SpeedTestError`, or `CancellationError` when the calling task is cancelled.
     */
    func measure() async throws -> Measurement? {
        let delegate = ProbeDelegate()
        let session = SpeedTestStream.makeSession(configuration: makeConfiguration(), delegate: delegate)
        return try await withTaskCancellationHandler {
            defer { delegate.close(session: session, cancelling: false) }
            var observations: [Observation] = []
            for _ in 0..<requestCount {
                if let observation = try await delegate.fetch(url: url, session: session) {
                    observations.append(observation)
                }
            }
            return Self.summarize(observations)
        } onCancel: {
            delegate.close(session: session, cancelling: true)
        }
    }

    /// The state of the one probe request in flight.
    private struct Pending {
        let continuation: CheckedContinuation<Observation?, Error>
        var metrics: URLSessionTaskMetrics?
        var isComplete = false
        var completionError: Error?
        var serverTimingMs: Double?
        var statusFailure: SpeedTestError?
        var receivedBytes: Int64 = 0
    }

    /// Receives the callbacks for the probe's session and resumes one request at a time.
    private final class ProbeDelegate: NSObject, URLSessionDataDelegate {
        private let lock = NSLock()
        private var pending: Pending?
        private var isClosed = false

        func fetch(url: URL, session: URLSession) async throws -> Observation? {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard !isClosed else {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pending = Pending(continuation: continuation)
                var request = URLRequest(url: url)
                request.setValue(SpeedTestStream.userAgent, forHTTPHeaderField: "User-Agent")
                let task = session.dataTask(with: request)
                lock.unlock()
                task.resume()
            }
        }

        func close(session: URLSession, cancelling: Bool) {
            lock.lock()
            guard !isClosed else {
                lock.unlock()
                return
            }
            isClosed = true
            lock.unlock()
            if cancelling {
                session.invalidateAndCancel()
            } else {
                session.finishTasksAndInvalidate()
            }
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            let http = response as? HTTPURLResponse
            let failure = CloudflareSpeedTestClient.failure(forStatusCode: http?.statusCode ?? 0)
            let header = http?.value(forHTTPHeaderField: "Server-Timing")
            let timing = SpeedTestLatencyProbe.serverTimingMs(fromHeader: header)
            lock.lock()
            if failure == nil {
                pending?.serverTimingMs = timing
            } else {
                pending?.statusFailure = failure
            }
            lock.unlock()
            completionHandler(failure == nil ? .allow : .cancel)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            lock.lock()
            pending?.receivedBytes += Int64(data.count)
            lock.unlock()
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didFinishCollecting metrics: URLSessionTaskMetrics
        ) {
            lock.lock()
            pending?.metrics = metrics
            let ready = takeIfComplete()
            let closed = isClosed
            lock.unlock()
            ready?.continuation.resume(with: outcome(of: ready, closed: closed))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            lock.lock()
            pending?.isComplete = true
            pending?.completionError = error
            let ready = error == nil ? takeIfComplete() : takePending()
            let closed = isClosed
            lock.unlock()
            ready?.continuation.resume(with: outcome(of: ready, closed: closed))
        }

        /// Hands back the pending request once it has completed and its metrics have arrived. Call with the lock held.
        private func takeIfComplete() -> Pending? {
            guard let state = pending, state.isComplete, state.metrics != nil else { return nil }
            return takePending()
        }

        /// Clears and returns the pending request. Call with the lock held.
        private func takePending() -> Pending? {
            defer { pending = nil }
            return pending
        }

        private func outcome(of state: Pending?, closed: Bool) -> Result<Observation?, Error> {
            guard let state else { return .success(nil) }
            if closed { return .failure(CancellationError()) }
            if let failure = state.statusFailure { return .failure(failure) }
            if let error = state.completionError { return .failure(SpeedTestStream.classify(error)) }
            if state.receivedBytes != 0 { return .failure(SpeedTestError.invalidResponse) }
            return .success(Self.observation(metrics: state.metrics, serverTimingMs: state.serverTimingMs))
        }

        private static func observation(metrics: URLSessionTaskMetrics?, serverTimingMs: Double?) -> Observation? {
            guard let transaction = metrics?.transactionMetrics.last,
                  let requestStart = transaction.requestStartDate,
                  let responseStart = transaction.responseStartDate else {
                return nil
            }
            return Observation(
                roundTripMs: responseStart.timeIntervalSince(requestStart) * 1000,
                serverTimingMs: serverTimingMs,
                isReusedConnection: transaction.isReusedConnection
            )
        }
    }
}
