import Testing
@testable import StatusMonitorCore

@Suite("RuleEvaluator")
struct RuleEvaluatorTests {
    private func rule(
        threshold: Double = 80,
        sustain: Double = 10,
        action: RuleAction = .notify,
        cooldown: Double = 0,
        enabled: Bool = true
    ) -> Rule {
        Rule(
            name: "test", metric: .cpuPercent, comparator: .greaterThan,
            threshold: threshold, sustainSeconds: sustain, action: action,
            cooldownSeconds: cooldown, dryRun: true, enabled: enabled
        )
    }

    private func step(
        _ rule: Rule, _ state: RuleRuntimeState, reading: Double?, elapsed: Double = 2, now: Double = 1_000
    ) -> RuleEvaluation {
        RuleEvaluator.evaluate(rule: rule, runtime: state, reading: reading, elapsedSeconds: elapsed, nowEpoch: now)
    }

    // MARK: - Sustain window

    @Test("a disabled rule is idle and never fires")
    func disabledIsIdle() {
        let r = rule(sustain: 0, enabled: false)
        let result = step(r, RuleRuntimeState(), reading: 99)
        #expect(result.phase == .idle)
        #expect(!result.fired)
    }

    @Test("a nil reading is idle, resets the streak, and never fires")
    func nilReadingResets() {
        let r = rule(sustain: 10)
        let watching = step(r, RuleRuntimeState(), reading: 90)
        #expect(watching.runtime.streakSeconds == 2)
        let missing = step(r, watching.runtime, reading: nil)
        #expect(missing.phase == .idle)
        #expect(missing.runtime.streakSeconds == 0)
        #expect(!missing.fired)
    }

    @Test("the condition must hold for the full sustain window before firing")
    func fireAfterSustain() {
        let r = rule(sustain: 6)
        var state = RuleRuntimeState()
        var fired = false
        for _ in 0..<3 {
            let result = step(r, state, reading: 90, elapsed: 2)
            state = result.runtime
            fired = fired || result.fired
        }
        #expect(fired)
        #expect(state.lastFiredAt == 1_000)
    }

    @Test("breaking the condition resets the streak to zero")
    func breakResetsStreak() {
        let r = rule(sustain: 6)
        let one = step(r, RuleRuntimeState(), reading: 90, elapsed: 4)
        #expect(one.runtime.streakSeconds == 4)
        let broken = step(r, one.runtime, reading: 10, elapsed: 4)
        #expect(broken.runtime.streakSeconds == 0)
        #expect(broken.phase == .idle)
    }

    @Test("the comparator is applied to the reading")
    func comparators() {
        #expect(RuleComparator.greaterThan.holds(81, 80))
        #expect(!RuleComparator.greaterThan.holds(80, 80))
        #expect(RuleComparator.greaterOrEqual.holds(80, 80))
        #expect(RuleComparator.lessThan.holds(79, 80))
        #expect(RuleComparator.lessOrEqual.holds(80, 80))
    }

    // MARK: - Cooldown

    @Test("after a fire the rule is cooling and cannot fire again inside the cooldown")
    func cooldownBlocksRefire() {
        let r = rule(sustain: 0, action: .notify, cooldown: 120)
        let fire = step(r, RuleRuntimeState(), reading: 90, now: 1_000)
        #expect(fire.fired)

        let during = step(r, fire.runtime, reading: 90, now: 1_000 + 119)
        #expect(during.phase == .cooling)
        #expect(!during.fired)

        let after = step(r, fire.runtime, reading: 90, now: 1_000 + 120)
        #expect(after.fired)
    }

    @Test("the effective cooldown is never below the action floor")
    func floorEnforced() {
        #expect(rule(action: .notify, cooldown: 5).effectiveCooldownSeconds == 60)
        #expect(rule(action: .script(path: "/x.sh"), cooldown: 5).effectiveCooldownSeconds == 300)
        #expect(rule(action: .clean(.standard), cooldown: 5).effectiveCooldownSeconds == 180)
        #expect(rule(action: .notify, cooldown: 600).effectiveCooldownSeconds == 600)
    }

    @Test("editing the threshold during cooldown keeps the remaining cooldown time")
    func editingThresholdKeepsCooldown() {
        let original = rule(threshold: 80, sustain: 0, action: .notify, cooldown: 120)
        let fire = step(original, RuleRuntimeState(), reading: 90, now: 1_000)
        #expect(fire.fired)

        // The user lowers the threshold so the condition is trivially true, and the rule is edited mid-cooldown.
        var edited = original
        edited.threshold = 1
        let during = step(edited, fire.runtime, reading: 90, now: 1_000 + 30)
        #expect(during.phase == .cooling)
        #expect(!during.fired)
        #expect(during.runtime.lastFiredAt == 1_000)
    }

    @Test("switching to a stricter action during cooldown can only lengthen the cooldown")
    func actionChangeCannotShorten() {
        let notify = rule(sustain: 0, action: .notify, cooldown: 60)
        let fire = step(notify, RuleRuntimeState(), reading: 90, now: 1_000)

        var escalated = notify
        escalated.action = .script(path: "/x.sh")
        // 60 s after the fire, the notify cooldown would have ended, but the script floor (300 s) has not.
        let during = step(escalated, fire.runtime, reading: 90, now: 1_000 + 60)
        #expect(during.phase == .cooling)
    }

    @Test("a lastFiredAt in the future (clock moved backwards) is clamped to now")
    func futureTimestampClamped() {
        let r = rule(sustain: 0, action: .notify, cooldown: 60)
        let state = RuleRuntimeState(streakSeconds: 0, lastFiredAt: 5_000)
        let result = step(r, state, reading: 90, now: 1_000)
        #expect(result.runtime.lastFiredAt == 1_000)
        #expect(result.phase == .cooling)
    }

    @Test("a streak built during cooldown does not carry over when cooldown ends")
    func streakDoesNotCarryOutOfCooldown() {
        let r = rule(sustain: 10, action: .notify, cooldown: 60)
        let state = RuleRuntimeState(streakSeconds: 8, lastFiredAt: 1_000)
        let during = step(r, state, reading: 90, elapsed: 2, now: 1_030)
        #expect(during.runtime.streakSeconds == 0)
    }
}

@Suite("ScriptRateLimiter")
struct ScriptRateLimiterTests {
    @Test("the first script run is always allowed")
    func firstRunAllowed() {
        #expect(ScriptRateLimiter.mayRun(lastScriptRunAt: nil, nowEpoch: 1_000))
    }

    @Test("a second run within 600 s is refused, and allowed after")
    func window() {
        #expect(!ScriptRateLimiter.mayRun(lastScriptRunAt: 1_000, nowEpoch: 1_599))
        #expect(ScriptRateLimiter.mayRun(lastScriptRunAt: 1_000, nowEpoch: 1_600))
    }

    @Test("a future last-run time is refused until it is clamped and stored")
    func futureLastRunRefused() {
        #expect(!ScriptRateLimiter.mayRun(lastScriptRunAt: 9_000, nowEpoch: 1_000))
    }

    @Test("once clamped and stored, a future timestamp expires 600 s after the clamp, not never")
    func clampedFutureLastRunExpires() {
        // The caller persists the clamp at now=1000. The window then runs from 1000, so it ends at 1600.
        let stored = ScriptRateLimiter.clampedLastRun(9_000, nowEpoch: 1_000)
        #expect(stored == 1_000)
        #expect(!ScriptRateLimiter.mayRun(lastScriptRunAt: stored, nowEpoch: 1_000 + 599))
        #expect(ScriptRateLimiter.mayRun(lastScriptRunAt: stored, nowEpoch: 1_000 + 600))
    }
}
