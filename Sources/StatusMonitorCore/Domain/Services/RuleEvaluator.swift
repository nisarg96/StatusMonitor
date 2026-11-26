import Foundation

/// Phase shown in the Rules tab.
public enum RulePhase: Equatable, Sendable {
    /// Disabled, or the metric has no reading right now.
    case idle
    /// Condition holds, but the sustain window has not yet elapsed.
    case watching
    /// Within the cooldown after a fire.
    case cooling
}

public struct RuleEvaluation: Equatable, Sendable {
    public var runtime: RuleRuntimeState
    public var phase: RulePhase
    /// True only on the tick the rule fires. The caller decides whether to execute or dry-run.
    public var fired: Bool
}

/// Pure state machine for one rule. Called once per tick, per rule.
///
/// Cooldown guarantees:
/// - The end of a cooldown is `lastFiredAt + effectiveCooldownSeconds`, and it is computed from the rule's
///   current action and cooldown each time. Editing a threshold therefore cannot shorten it. Switching to a
///   stricter action can only lengthen it.
/// - `lastFiredAt` lives in runtime state, which the rule editor never writes.
/// - A `lastFiredAt` in the future (clock moved backwards) is clamped to `now`, so it cannot lock a rule forever.
public enum RuleEvaluator {
    public static func evaluate(
        rule: Rule,
        runtime: RuleRuntimeState,
        reading: Double?,
        elapsedSeconds: Double,
        nowEpoch: Double
    ) -> RuleEvaluation {
        var state = runtime

        guard rule.enabled, let reading else {
            state.streakSeconds = 0
            return RuleEvaluation(runtime: state, phase: .idle, fired: false)
        }

        if let last = state.lastFiredAt {
            if last > nowEpoch {
                state.lastFiredAt = nowEpoch
            }
            let cooldownEnd = (state.lastFiredAt ?? nowEpoch) + rule.effectiveCooldownSeconds
            if nowEpoch < cooldownEnd {
                // Cooldown is not cumulative. A streak built during cooldown does not carry over.
                state.streakSeconds = 0
                return RuleEvaluation(runtime: state, phase: .cooling, fired: false)
            }
        }

        guard rule.comparator.holds(reading, rule.threshold) else {
            state.streakSeconds = 0
            return RuleEvaluation(runtime: state, phase: .idle, fired: false)
        }

        state.streakSeconds += max(0, elapsedSeconds)
        if state.streakSeconds >= rule.sustainSeconds {
            state.streakSeconds = 0
            state.lastFiredAt = nowEpoch
            return RuleEvaluation(runtime: state, phase: .cooling, fired: true)
        }
        return RuleEvaluation(runtime: state, phase: .watching, fired: false)
    }
}

/// Global limit on script executions, across all script rules and clean actions.
public enum ScriptRateLimiter {
    public static let windowSeconds: Double = 600

    /// Returns true when a script may run now. A last-run time in the future is refused until the caller
    /// normalises it with `clampedLastRun` and persists the result. Clamping here would reset the window on every
    /// call, so a clock that moved backwards would block runs forever.
    public static func mayRun(lastScriptRunAt: Double?, nowEpoch: Double) -> Bool {
        guard let last = lastScriptRunAt else { return true }
        if last > nowEpoch { return false }
        return nowEpoch >= last + windowSeconds
    }

    /// Clamps a last-run time that lies in the future to `now`. The caller must store the result,
    /// so the 600 s window starts from the clamp, not from the bad timestamp.
    public static func clampedLastRun(_ lastScriptRunAt: Double?, nowEpoch: Double) -> Double? {
        guard let last = lastScriptRunAt else { return nil }
        return min(last, nowEpoch)
    }
}
