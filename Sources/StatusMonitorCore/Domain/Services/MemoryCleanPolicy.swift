import Foundation

/// Available memory in bytes: free + inactive + purgeable pages, times the page size.
/// This is the single formula used everywhere. The Clean report and Auto Clean both use it, so their numbers agree.
public enum AvailableMemoryCalculator {
    public static func availableBytes(
        freePages: UInt64,
        inactivePages: UInt64,
        purgeablePages: UInt64,
        pageSize: UInt64
    ) -> UInt64 {
        (freePages &+ inactivePages &+ purgeablePages) &* pageSize
    }
}

/// Auto Clean threshold, expressed as a percentage of physical RAM in use.
/// Auto Clean runs when used RAM reaches the threshold. The slider offers 70% to 100% in 5% steps.
public enum AutoCleanThreshold {
    public static let defaultPercent = 85
    public static let minimumPercent = 70
    public static let maximumPercent = 100
    public static let stepPercent = 5

    /// Every stop on the slider, in order.
    public static let stops: [Int] = Array(stride(from: minimumPercent, through: maximumPercent, by: stepPercent))

    /// Clamps to 70...100 and snaps to the nearest 5% step, so a stored or typed value always lands on a slider stop.
    public static func snapped(_ percent: Int) -> Int {
        let clamped = min(maximumPercent, max(minimumPercent, percent))
        let steps = Int((Double(clamped - minimumPercent) / Double(stepPercent)).rounded())
        return min(maximumPercent, minimumPercent + steps * stepPercent)
    }

    /// Free memory left at a threshold, in GB. Shown next to the slider so the percentage has a concrete meaning.
    public static func freeGBAt(percent: Int, physicalRAMBytes: UInt64) -> Double {
        let free = Double(physicalRAMBytes) * Double(100 - percent) / 100
        return free / 1_073_741_824
    }
}

/// Decision for one Auto Clean tick. Pure, so the threshold, sustain, re-arm, cooldown, pause and skip reasons are
/// testable without a timer.
public enum AutoCleanDecision: Equatable, Sendable {
    case clean
    case skip(reason: SkipReason)

    public enum SkipReason: String, Equatable, Sendable {
        case disabled = "auto clean is off"
        case paused = "paused after 3 failed cleans"
        case cleanInProgress = "a clean is already running"
        case waitingForRearm = "waiting for RAM to drop"
        case belowThreshold = "RAM used below threshold"
        case notSustained = "RAM high for under 30 s"
        case cooldown = "cooldown"
        case helperNotAvailable = "helper not available"
    }

    /// Cooldown floor for Auto Clean, and the cooldown after a clean that frees enough memory. Not overridable.
    public static let cooldownSeconds: Double = 180
    /// Ceiling for the cooldown after ineffective cleans.
    public static let maxCooldownSeconds: Double = 1_800
    /// Used RAM must stay continuously below the threshold for this many monotonic seconds before the backoff
    /// cooldown returns to the floor. A shorter dip, including the re-arm dip, leaves the backoff in place.
    public static let cooldownResetBelowSeconds: Double = 600
    /// Used RAM must stay at or above the threshold for this many monotonic seconds before a clean runs.
    public static let sustainSeconds: Double = 30
    /// Auto Clean re-arms only once used RAM is this many points below the threshold.
    public static let rearmMarginPercent = 5
    /// A clean that frees at least this many bytes counts as effective. Binary megabytes: 256 MiB.
    public static let effectiveFreedBytes: Int64 = 256 * 1_048_576
    /// Consecutive failed cleans (non-zero exit, or a timeout) that pause Auto Clean.
    public static let maxConsecutiveFailures = 3

    /// - Parameters:
    ///   - inputs: the settings and readings for this tick. `usedPercent` is used RAM as a percentage of physical RAM.
    ///   - helperAvailable: an autoclosure, so the helper check (which may spawn a process) runs only when a clean
    ///     is otherwise due.
    public static func evaluate(
        _ inputs: AutoCleanInputs,
        helperAvailable: @autoclosure () -> Bool
    ) -> AutoCleanDecision {
        if let reason = blockingReason(inputs) { return .skip(reason: reason) }
        guard helperAvailable() else { return .skip(reason: .helperNotAvailable) }
        return .clean
    }

    /// Used RAM has been at or above the threshold for `sustainSeconds`, using the monotonic clock.
    public static func isSustained(_ inputs: AutoCleanInputs) -> Bool {
        guard let start = inputs.sustainStartSeconds else { return false }
        return inputs.monotonicNowSeconds - start >= sustainSeconds
    }

    /// Re-arm rule: used RAM is strictly below the threshold minus `rearmMarginPercent`.
    public static func rearms(usedPercent: Double, thresholdPercent: Int) -> Bool {
        let line = Double(AutoCleanThreshold.snapped(thresholdPercent) - rearmMarginPercent)
        return usedPercent < line
    }

    /// Cooldown after a finished automatic clean. Freeing at least `effectiveFreedBytes` resets it to the floor.
    /// Any other result doubles it, up to `maxCooldownSeconds`. An unmeasured result is not proven effective, so it
    /// doubles too.
    public static func nextCooldown(current: Double, freedBytes: Int64?) -> Double {
        if let freed = freedBytes, freed >= effectiveFreedBytes { return cooldownSeconds }
        return min(current * 2, maxCooldownSeconds)
    }

    /// True once used RAM has been continuously below the threshold for `cooldownResetBelowSeconds`.
    /// `belowSinceSeconds` is the monotonic time the current dip began, or nil when used RAM is not below it now.
    public static func belowLongEnoughToResetCooldown(
        belowSinceSeconds: Double?, monotonicNowSeconds: Double
    ) -> Bool {
        guard let since = belowSinceSeconds else { return false }
        return monotonicNowSeconds - since >= cooldownResetBelowSeconds
    }

    /// The first rule that stops a clean, in the order the rules apply. Nil when a clean is due.
    static func blockingReason(_ inputs: AutoCleanInputs) -> SkipReason? {
        guard inputs.enabled else { return .disabled }
        guard !inputs.paused else { return .paused }
        guard !inputs.cleanInProgress else { return .cleanInProgress }
        guard inputs.armed else { return .waitingForRearm }
        guard inputs.usedPercent >= Double(AutoCleanThreshold.snapped(inputs.thresholdPercent)) else {
            return .belowThreshold
        }
        guard isSustained(inputs) else { return .notSustained }
        return inCooldown(inputs) ? .cooldown : nil
    }

    /// A future timestamp counts as in cooldown until the caller clamps and stores it. Clamping here would reset the
    /// window every tick.
    static func inCooldown(_ inputs: AutoCleanInputs) -> Bool {
        guard let last = inputs.lastCleanAt else { return false }
        return last > inputs.nowEpoch || inputs.nowEpoch < last + inputs.cooldownSeconds
    }
}
