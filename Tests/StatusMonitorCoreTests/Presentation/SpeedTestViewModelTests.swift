import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestViewModel", .timeLimit(.minutes(1)))
@MainActor
struct SpeedTestViewModelTests {
    private let sample = SpeedTestResult(
        downloadMbps: 80, uploadMbps: 20, latencyMs: 12, jitterMs: 1.5,
        measuredAt: Date(timeIntervalSince1970: 0)
    )

    /// The view model under test, with the fake port and clock it was built from.
    private struct Harness {
        let model: SpeedTestViewModel
        let port: FakeSpeedTestPort
        let clock: FakeClock
    }

    private func makeModel(_ script: FakeSpeedTestScript) -> Harness {
        let port = FakeSpeedTestPort(script: script)
        let clock = FakeClock()
        return Harness(model: SpeedTestViewModel(port: port, clock: clock), port: port, clock: clock)
    }

    /// Polls until `condition` holds or about two seconds pass, so the main actor can run the pending work.
    private func settle(_ condition: @MainActor () -> Bool) async {
        var attempts = 0
        while !condition(), attempts < 2_000 {
            try? await Task.sleep(nanoseconds: 1_000_000)
            attempts += 1
        }
    }

    private func expectedMessage(for error: SpeedTestError) -> String {
        switch error {
        case .offline:
            return "You appear to be offline."
        case .serviceUnavailable:
            return "The speed test service is unavailable right now."
        case .rateLimited:
            return "Speed test is cooling down. Try again in a few seconds."
        case .invalidResponse:
            return "The speed test got an unexpected response."
        case .cancelled:
            return ""
        }
    }

    @Test("a run calls the port once and ends with the result")
    func runCallsPortOnce() async {
        let harness = makeModel(.succeed(sample))
        let model = harness.model
        let port = harness.port
        #expect(model.state == .idle)
        model.run()
        await settle { model.state == .done(sample) }
        #expect(model.state == .done(sample))
        #expect(port.callCount == 1)
    }

    @Test("a second run within 10 seconds is refused with the cooldown message")
    func cooldownRefusesSecondRun() async {
        let harness = makeModel(.succeed(sample))
        let model = harness.model
        let port = harness.port
        let clock = harness.clock
        model.run()
        await settle { model.state == .done(sample) }
        clock.advance(seconds: 5)
        model.run()
        #expect(model.state == .failed("Speed test is cooling down. Try again in a few seconds."))
        #expect(port.callCount == 1)
    }

    @Test("a run 10 seconds after the last one starts proceeds")
    func runAfterCooldownProceeds() async {
        let harness = makeModel(.succeed(sample))
        let model = harness.model
        let port = harness.port
        let clock = harness.clock
        model.run()
        await settle { model.state == .done(sample) }
        clock.advance(seconds: 10)
        model.run()
        await settle { port.callCount == 2 }
        #expect(port.callCount == 2)
        await settle { model.state == .done(sample) }
        #expect(model.state == .done(sample))
    }

    @Test("cancel returns the state to idle and the port sees the cancellation")
    func cancelReturnsToIdle() async {
        let harness = makeModel(.hang(progress: []))
        let model = harness.model
        let port = harness.port
        model.run()
        await settle { port.callCount == 1 }
        model.cancel()
        #expect(model.state == .idle)
        await settle { port.cancelledCount == 1 }
        #expect(port.cancelledCount == 1)
        #expect(model.state == .idle)
    }

    @Test("a run while one is in progress is ignored")
    func runWhileRunningIsIgnored() async {
        let harness = makeModel(.hang(progress: []))
        let model = harness.model
        let port = harness.port
        model.run()
        await settle { port.callCount == 1 }
        model.run()
        #expect(port.callCount == 1)
        #expect(model.isRunning)
        #expect(model.state == .running(.latency))
        model.cancel()
    }

    @Test("progress from the port updates the running state")
    func progressUpdatesRunningState() async {
        let harness = makeModel(.hang(progress: [.download(42.5)]))
        let model = harness.model
        model.run()
        await settle { model.state == .running(.download(42.5)) }
        #expect(model.state == .running(.download(42.5)))
        model.cancel()
    }

    @Test("each failure shows its message", arguments: [
        SpeedTestError.offline, .serviceUnavailable, .rateLimited, .invalidResponse
    ])
    func failureShowsMessage(error: SpeedTestError) async {
        let harness = makeModel(.fail(error))
        let model = harness.model
        model.run()
        await settle { model.state != .running(.latency) && model.state != .idle }
        #expect(model.state == .failed(expectedMessage(for: error)))
    }

    @Test("a cancelled error from the port returns to idle without a message")
    func cancelledErrorReturnsToIdle() async {
        let harness = makeModel(.fail(.cancelled))
        let model = harness.model
        let port = harness.port
        model.run()
        await settle { port.callCount == 1 && !model.isRunning }
        #expect(model.state == .idle)
    }

    @Test("a result that arrives after cancel does not replace the idle state")
    func lateResultIgnoredAfterCancel() async {
        let harness = makeModel(.ignoreCancellation(sample))
        let model = harness.model
        let port = harness.port
        model.run()
        await settle { port.callCount == 1 }
        model.cancel()
        await settle { port.returnedCount == 1 }
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(model.state == .idle)
    }
}
