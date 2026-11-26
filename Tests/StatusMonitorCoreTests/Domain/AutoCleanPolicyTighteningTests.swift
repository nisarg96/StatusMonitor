import Testing
@testable import StatusMonitorCore

/// Counts helper checks. Passed through the decision's autoclosure, so a check runs only when it is evaluated.
private final class TightenHelperProbe {
    private(set) var checks = 0

    func available() -> Bool {
        checks += 1
        return true
    }
}

@Suite("AutoCleanDecision tightening")
struct AutoCleanDecisionTighteningTests {
    private static let mib: Int64 = 1024 * 1024

    /// Inputs that pass every rule except the one a test changes.
    private static func ready(usedPercent: Double = 95) -> AutoCleanInputs {
        var inputs = AutoCleanInputs(
            enabled: true, usedPercent: usedPercent, thresholdPercent: 85, lastCleanAt: nil, nowEpoch: 1_000
        )
        inputs.sustainStartSeconds = 0
        inputs.monotonicNowSeconds = 30
        return inputs
    }

    @Test("exactly 30 s of sustain is enough, 29.9 s is not")
    func sustainBoundary() {
        var inputs = Self.ready()
        inputs.monotonicNowSeconds = 29.9
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .skip(reason: .notSustained))
        inputs.monotonicNowSeconds = 30
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .clean)
    }

    @Test("with no sustain start, RAM is not sustained")
    func noSustainStart() {
        var inputs = Self.ready()
        inputs.sustainStartSeconds = nil
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .skip(reason: .notSustained))
    }

    @Test("while paused it skips with the pause reason")
    func pausedReason() {
        var inputs = Self.ready()
        inputs.paused = true
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .skip(reason: .paused))
    }

    @Test("while disarmed it waits for RAM to drop")
    func disarmedReason() {
        var inputs = Self.ready()
        inputs.armed = false
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .skip(reason: .waitingForRearm))
    }

    @Test("a clean already running blocks another one")
    func cleanInProgressReason() {
        var inputs = Self.ready()
        inputs.cleanInProgress = true
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: true) == .skip(reason: .cleanInProgress))
    }

    @Test("the helper is not checked while a pause blocks the clean")
    func helperCheckLazyUnderPause() {
        var inputs = Self.ready()
        inputs.paused = true
        let probe = TightenHelperProbe()
        #expect(AutoCleanDecision.evaluate(inputs, helperAvailable: probe.available()) == .skip(reason: .paused))
        #expect(probe.checks == 0)
    }

    @Test("a clean's freed memory sets the next cooldown: double, cap at 1800, reset at 256 MiB")
    func backoffRule() {
        #expect(AutoCleanDecision.nextCooldown(current: 180, freedBytes: 0) == 360)
        #expect(AutoCleanDecision.nextCooldown(current: 360, freedBytes: 255 * Self.mib) == 720)
        #expect(AutoCleanDecision.nextCooldown(current: 720, freedBytes: 256 * Self.mib - 1) == 1_440)
        #expect(AutoCleanDecision.nextCooldown(current: 1_440, freedBytes: nil) == 1_800)
        #expect(AutoCleanDecision.nextCooldown(current: 1_800, freedBytes: 0) == 1_800)
        #expect(AutoCleanDecision.nextCooldown(current: 1_440, freedBytes: 256 * Self.mib) == 180)
        #expect(AutoCleanDecision.nextCooldown(current: 1_800, freedBytes: 4_096 * Self.mib) == 180)
    }

    @Test("re-arm needs RAM strictly below threshold minus 5")
    func rearmLine() {
        #expect(AutoCleanDecision.rearms(usedPercent: 79.9, thresholdPercent: 85))
        #expect(!AutoCleanDecision.rearms(usedPercent: 80, thresholdPercent: 85))
    }

    @Test("the policy constants match the approved values")
    func constants() {
        #expect(AutoCleanDecision.cooldownSeconds == 180)
        #expect(AutoCleanDecision.maxCooldownSeconds == 1_800)
        #expect(AutoCleanDecision.sustainSeconds == 30)
        #expect(AutoCleanDecision.maxConsecutiveFailures == 3)
        #expect(AutoCleanDecision.effectiveFreedBytes == 256 * Self.mib)
    }
}
