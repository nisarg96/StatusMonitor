import Foundation
import Testing
@testable import StatusMonitorCore

// Every request in this file is answered by SpeedTestStubProtocol. The base URL uses the reserved .invalid host,
// so a request that escaped the stub could not reach a real server either.

enum SpeedTestStubReply: Sendable {
    case respond(status: Int, bodyBytes: Int)
    case fail(URLError.Code)
    case hold
}

typealias SpeedTestStubHandler = @Sendable (_ path: String, _ bytes: Int?) -> SpeedTestStubReply

final class SpeedTestStubBook: @unchecked Sendable {
    static let shared = SpeedTestStubBook()

    private let lock = NSLock()
    private var handler: SpeedTestStubHandler = { _, _ in .respond(status: 200, bodyBytes: 0) }
    private var started = 0
    private var stopped = 0
    private var unexpected: [String] = []

    func reset(handler: @escaping SpeedTestStubHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        started = 0
        stopped = 0
        unexpected = []
    }

    func currentHandler() -> SpeedTestStubHandler {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }

    func recordStart() {
        lock.lock()
        defer { lock.unlock() }
        started += 1
    }

    func recordStop() {
        lock.lock()
        defer { lock.unlock() }
        stopped += 1
    }

    func recordUnexpected(_ description: String) {
        lock.lock()
        defer { lock.unlock() }
        unexpected.append(description)
    }

    var requestsStarted: Int {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    var requestsStopped: Int {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    var unexpectedRequests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return unexpected
    }
}

class SpeedTestStubProtocol: URLProtocol {
    static let host = "speed.test.invalid"
    static let userAgent = "StatusMonitor speed test"

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        SpeedTestStubBook.shared.recordStart()
        guard let url = request.url, let stubbed = Self.stubbedRoute(for: url), hasExpectedUserAgent else {
            SpeedTestStubBook.shared.recordUnexpected(request.url?.absoluteString ?? "<no URL>")
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if stubbed.path == "/__up" {
            Self.drain(request.httpBodyStream)
        }
        switch SpeedTestStubBook.shared.currentHandler()(stubbed.path, stubbed.bytes) {
        case let .respond(status, bodyBytes):
            respond(url: url, status: status, bodyBytes: bodyBytes)
        case let .fail(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hold:
            break
        }
    }

    override func stopLoading() {
        SpeedTestStubBook.shared.recordStop()
    }

    private var hasExpectedUserAgent: Bool {
        request.value(forHTTPHeaderField: "User-Agent") == Self.userAgent
    }

    private static func stubbedRoute(for url: URL) -> (path: String, bytes: Int?)? {
        guard url.host == host, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []
        switch components.path {
        case "/__down":
            guard items.count == 1, items[0].name == "bytes", let value = items[0].value, let count = Int(value) else {
                return nil
            }
            return ("/__down", count)
        case "/__up":
            return items.isEmpty ? ("/__up", nil) : nil
        default:
            return nil
        }
    }

    private static func drain(_ stream: InputStream?) {
        guard let stream else { return }
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            if stream.read(&buffer, maxLength: buffer.count) <= 0 { break }
        }
    }

    private func respond(url: URL, status: Int, bodyBytes: Int) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Server-Timing": "cfRequestDuration;dur=0"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        var remaining = bodyBytes
        while remaining > 0 {
            let chunk = min(remaining, 65_536)
            client?.urlProtocol(self, didLoad: Data(count: chunk))
            remaining -= chunk
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite("CloudflareSpeedTestClient", .serialized, .timeLimit(.minutes(1)))
struct CloudflareSpeedTestClientTests {
    private let testBase = URL(string: "https://speed.test.invalid")!

    private var fastTuning: CloudflareSpeedTestClient.Tuning {
        CloudflareSpeedTestClient.Tuning(
            parallelStreams: 2,
            downloadRequestBytes: 200_000,
            uploadBodyBytes: 50_000,
            downloadCap: Int64.max,
            uploadCap: Int64.max,
            latencyRequests: 3,
            warmUpCeiling: 0.1,
            measuredDuration: 0.3,
            sampleInterval: 0.05,
            uploadCountingDelay: 0
        )
    }

    private func makeClient(tuning: CloudflareSpeedTestClient.Tuning? = nil) -> CloudflareSpeedTestClient {
        CloudflareSpeedTestClient(
            baseURL: testBase,
            makeConfiguration: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [SpeedTestStubProtocol.self]
                return configuration
            },
            clock: CloudflareSpeedTestClient.systemClock,
            tuning: tuning ?? fastTuning
        )
    }

    private func expectNoUnexpectedRequests() {
        #expect(SpeedTestStubBook.shared.unexpectedRequests.isEmpty)
    }

    @Test("the default base URL is the Cloudflare endpoint")
    func defaultBaseURL() {
        #expect(CloudflareSpeedTestClient.defaultBaseURL.absoluteString == "https://speed.cloudflare.com")
    }

    @Test("a download run returns a download rate, and packet loss is not measured")
    func downloadRunReturnsResult() async throws {
        SpeedTestStubBook.shared.reset { path, bytes in
            path == "/__down" ? .respond(status: 200, bodyBytes: bytes ?? 0) : .respond(status: 200, bodyBytes: 0)
        }
        let result = try await makeClient().run { _ in }
        let downloadMbps = try #require(result.downloadMbps)
        #expect(downloadMbps > 0)
        #expect(result.packetLossPercent == nil)
        expectNoUnexpectedRequests()
    }

    @Test("an offline error maps to offline and stops at the first request")
    func offlineStopsAtFirstRequest() async {
        SpeedTestStubBook.shared.reset { _, _ in .fail(.notConnectedToInternet) }
        await #expect(throws: SpeedTestError.offline) {
            try await makeClient().run { _ in }
        }
        #expect(SpeedTestStubBook.shared.requestsStarted == 1)
        expectNoUnexpectedRequests()
    }

    @Test("a 500 status maps to serviceUnavailable")
    func serverErrorMapsToServiceUnavailable() async {
        SpeedTestStubBook.shared.reset { _, _ in .respond(status: 500, bodyBytes: 0) }
        await #expect(throws: SpeedTestError.serviceUnavailable) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }

    @Test("every download stream failing with a 500 maps to serviceUnavailable while latency succeeds")
    func allDownloadStreamsFailing() async {
        SpeedTestStubBook.shared.reset { path, bytes in
            let isDownload = path == "/__down" && (bytes ?? 0) > 0
            return isDownload ? .respond(status: 500, bodyBytes: 0) : .respond(status: 200, bodyBytes: 0)
        }
        await #expect(throws: SpeedTestError.serviceUnavailable) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }

    @Test("a latency body that disagrees with the request maps to invalidResponse")
    func shortBodyMapsToInvalidResponse() async {
        SpeedTestStubBook.shared.reset { _, _ in .respond(status: 200, bodyBytes: 5) }
        await #expect(throws: SpeedTestError.invalidResponse) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }

    @Test("cancelling the run invalidates the session and throws cancelled")
    func cancellationInvalidatesSession() async throws {
        SpeedTestStubBook.shared.reset { _, _ in .hold }
        let client = makeClient()
        let task = Task { try await client.run { _ in } }
        var waited = 0
        while SpeedTestStubBook.shared.requestsStarted == 0 && waited < 200 {
            try await Task.sleep(nanoseconds: 10_000_000)
            waited += 1
        }
        task.cancel()
        await #expect(throws: SpeedTestError.cancelled) {
            try await task.value
        }
        #expect(SpeedTestStubBook.shared.requestsStopped >= 1)
        expectNoUnexpectedRequests()
    }

    @Test("a 429 on a download stream maps to rateLimited")
    func downloadTooManyRequestsMapsToRateLimited() async {
        SpeedTestStubBook.shared.reset { path, bytes in
            let isDownload = path == "/__down" && (bytes ?? 0) > 0
            return isDownload ? .respond(status: 429, bodyBytes: 0) : .respond(status: 200, bodyBytes: 0)
        }
        await #expect(throws: SpeedTestError.rateLimited) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }

    @Test("a 503 on a download stream maps to serviceUnavailable")
    func downloadServiceUnavailableMapsToServiceUnavailable() async {
        SpeedTestStubBook.shared.reset { path, bytes in
            let isDownload = path == "/__down" && (bytes ?? 0) > 0
            return isDownload ? .respond(status: 503, bodyBytes: 0) : .respond(status: 200, bodyBytes: 0)
        }
        await #expect(throws: SpeedTestError.serviceUnavailable) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }

    @Test("a 503 on the upload maps to serviceUnavailable")
    func uploadServiceUnavailableMapsToServiceUnavailable() async {
        SpeedTestStubBook.shared.reset { path, bytes in
            if path == "/__up" {
                return .respond(status: 503, bodyBytes: 0)
            }
            return .respond(status: 200, bodyBytes: bytes ?? 0)
        }
        await #expect(throws: SpeedTestError.serviceUnavailable) {
            try await makeClient().run { _ in }
        }
        expectNoUnexpectedRequests()
    }
}
