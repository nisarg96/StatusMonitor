import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestMessages")
struct SpeedTestMessagesTests {
    @Test("offline shows the offline message")
    func offline() {
        #expect(SpeedTestMessages.message(for: SpeedTestError.offline) == "You appear to be offline.")
    }

    @Test("serviceUnavailable shows the unavailable message")
    func serviceUnavailable() {
        #expect(SpeedTestMessages.message(for: SpeedTestError.serviceUnavailable)
            == "The speed test service is unavailable right now.")
    }

    @Test("rateLimited shows the cooldown message")
    func rateLimited() {
        #expect(SpeedTestMessages.message(for: SpeedTestError.rateLimited)
            == "Speed test is cooling down. Try again in a few seconds.")
        #expect(SpeedTestMessages.message(for: SpeedTestError.rateLimited) == SpeedTestMessages.cooldown)
    }

    @Test("invalidResponse shows the unexpected response message")
    func invalidResponse() {
        #expect(SpeedTestMessages.message(for: SpeedTestError.invalidResponse)
            == "The speed test got an unexpected response.")
    }

    @Test("cancelled has no message, so the state returns to idle")
    func cancelled() {
        #expect(SpeedTestMessages.message(for: SpeedTestError.cancelled) == nil)
        #expect(SpeedTestMessages.message(for: CancellationError()) == nil)
    }

    @Test("an unknown error shows the unavailable message")
    func unknownError() {
        #expect(SpeedTestMessages.message(for: URLError(.timedOut))
            == "The speed test service is unavailable right now.")
    }
}
