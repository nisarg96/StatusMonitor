import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestStream")
struct SpeedTestStreamTests {
    @Test("session configuration sets the timeouts, the User-Agent, and no cache or cookies")
    func sessionConfiguration() {
        let configuration = SpeedTestStream.configure(URLSessionConfiguration.ephemeral)
        #expect(configuration.timeoutIntervalForRequest == 10)
        #expect(configuration.timeoutIntervalForResource == 30)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.httpAdditionalHeaders?["User-Agent"] as? String == "StatusMonitor speed test")
    }

    @Test("a not-connected URLError classifies as offline")
    func classifiesOffline() {
        #expect(SpeedTestStream.classify(URLError(.notConnectedToInternet)) == .offline)
    }

    @Test("other URLErrors classify as serviceUnavailable")
    func classifiesServiceErrors() {
        #expect(SpeedTestStream.classify(URLError(.timedOut)) == .serviceUnavailable)
    }

    @Test("cancellation classifies as cancelled, and a SpeedTestError passes through")
    func classifiesCancellation() {
        #expect(SpeedTestStream.classify(CancellationError()) == .cancelled)
        #expect(SpeedTestStream.classify(URLError(.cancelled)) == .cancelled)
        #expect(SpeedTestStream.classify(SpeedTestError.invalidResponse) == .invalidResponse)
    }
}
