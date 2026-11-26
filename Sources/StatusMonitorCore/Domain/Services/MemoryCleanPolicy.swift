import Foundation

/**
 Available memory in bytes: free + inactive + purgeable pages, times the page size.

 This is the single formula used everywhere. The Clean report and Auto Clean both use it, so their numbers agree.
 */
public enum AvailableMemoryCalculator {
    /**
     Returns the available memory in bytes.

     - Parameters:
       - freePages: The number of free pages.
       - inactivePages: The number of inactive pages.
       - purgeablePages: The number of purgeable pages.
       - pageSize: The page size in bytes.
     - Returns: Available memory in bytes.
     */
    public static func availableBytes(
        freePages: UInt64,
        inactivePages: UInt64,
        purgeablePages: UInt64,
        pageSize: UInt64
    ) -> UInt64 {
        (freePages &+ inactivePages &+ purgeablePages) &* pageSize
    }
}

/**
 Auto Clean threshold, expressed as a percentage of physical RAM in use.

 Auto Clean runs when used RAM reaches the threshold. The slider offers 70% to 100% in 5% steps.
 */
public enum AutoCleanThreshold {
    /// The default threshold, in percent of physical RAM in use.
    public static let defaultPercent = 85
    /// The lowest threshold the slider offers, in percent.
    public static let minimumPercent = 70
    /// The highest threshold the slider offers, in percent.
    public static let maximumPercent = 100
    /// The slider step, in percentage points.
    public static let stepPercent = 5

    /// Every stop on the slider, in order.
    public static let stops: [Int] = Array(stride(from: minimumPercent, through: maximumPercent, by: stepPercent))

    /**
     Snaps a percentage to the nearest slider stop.

     Clamps to 70...100 and snaps to the nearest 5% step, so a stored or typed value always lands on a slider stop.

     - Parameter percent: The percentage to snap.
     - Returns: The slider stop, from 70 to 100 in 5-point steps.
     */
    public static func snapped(_ percent: Int) -> Int {
        let clamped = min(maximumPercent, max(minimumPercent, percent))
        let steps = Int((Double(clamped - minimumPercent) / Double(stepPercent)).rounded())
        return min(maximumPercent, minimumPercent + steps * stepPercent)
    }

    /**
     Returns the free memory left at a threshold, in GiB.

     Shown next to the slider so the percentage has a concrete meaning.

     - Parameters:
       - percent: The threshold as a whole percentage of physical RAM.
       - physicalRAMBytes: Total physical memory in bytes.
     - Returns: Free memory in GiB (1 GiB is 1024^3 bytes).
     */
    public static func freeGBAt(percent: Int, physicalRAMBytes: UInt64) -> Double {
        let free = Double(physicalRAMBytes) * Double(100 - percent) / 100
        return free / 1_073_741_824
    }
}

/**
 Decision for one Auto Clean tick.

 Pure, so the threshold, sustain, re-arm, cooldown, pause and skip reasons are testable without a timer.
 */
public enum AutoCleanDecision: Equatable, Sendable {
    /// Start a clean now.
    case clean
    /// Do not clean this tick, for the given reason.
    case skip(reason: SkipReason)

    /// Why Auto Clean skipped a tick.
    public enum SkipReason: String, Equatable, Sendable {
        /// Auto Clean is switched off.
        case disabled = "auto clean is off"
        /// Auto Clean is paused after three failed cleans in a row.
        case paused = "paused after 3 failed cleans"
        /// A clean, automatic or manual, already holds the shared slot.
        case cleanInProgress = "a clean is already running"
        /// The last clean is not yet followed by a drop in used RAM below the re-arm line.
        case waitingForRearm = "waiting for RAM to drop"
        /// Used RAM is below the threshold.
        case belowThreshold = "RAM used below threshold"
        /// Used RAM has not stayed at or above the threshold for `sustainSeconds`.
        case notSustained = "RAM high for under 30 s"
        /// The cooldown after the last clean has not ended.
        case cooldown = "cooldown"
        /// The purge helper is not available.
        case helperNotAvailable = "helper not available"
    }

    /**
     The Auto Clean cooldown floor, in seconds. Not overridable.

     A clean that frees enough memory resets the cooldown to this value.
     */
    public static let cooldownSeconds: Double = 180
    /// The ceiling for the cooldown after ineffective cleans, in seconds.
    public static let maxCooldownSeconds: Double = 1_800
    /**
     The continuous dip below the threshold, in monotonic seconds, that returns the cooldown to the floor.

     Used RAM must stay below the threshold for this long before the backoff cooldown returns to the floor. A shorter
     dip, including the re-arm dip, leaves the backoff in place.
     */
    public static let cooldownResetBelowSeconds: Double = 600
    /// Used RAM must stay at or above the threshold for this many monotonic seconds before a clean runs.
    public static let sustainSeconds: Double = 30
    /// Auto Clean re-arms only once used RAM is this many points below the threshold.
    public static let rearmMarginPercent = 5
    /// A clean that frees at least this many bytes counts as effective. Binary megabytes: 256 MiB.
    public static let effectiveFreedBytes: Int64 = 256 * 1_048_576
    /// Consecutive failed cleans (non-zero exit, or a timeout) that pause Auto Clean.
    public static let maxConsecutiveFailures = 3

    /**
     Decides whether this tick should start a clean.

     The rules are checked first. The helper check runs only when a clean is otherwise due.

     - Parameters:
       - inputs: The settings and readings for this tick. `usedPercent` is used RAM as a percentage of physical RAM.
       - helperAvailable: An autoclosure, so the helper check (which may spawn a process) runs only when a clean is
         otherwise due.
     - Returns: `.clean` when a clean is due, or `.skip` with the reason it must wait.
     */
    public static func evaluate(
        _ inputs: AutoCleanInputs,
        helperAvailable: @autoclosure () -> Bool
    ) -> AutoCleanDecision {
        if let reason = blockingReason(inputs) { return .skip(reason: reason) }
        guard helperAvailable() else { return .skip(reason: .helperNotAvailable) }
        return .clean
    }

    /**
     Reports whether used RAM has been at or above the threshold for `sustainSeconds`.

     The check uses the monotonic clock.

     - Parameter inputs: The readings for this tick, including the monotonic sustain start.
     - Returns: True when the sustain period has elapsed.
     */
    public static func isSustained(_ inputs: AutoCleanInputs) -> Bool {
        guard let start = inputs.sustainStartSeconds else { return false }
        return inputs.monotonicNowSeconds - start >= sustainSeconds
    }

    /**
     Reports whether used RAM has fallen far enough below the threshold to re-arm Auto Clean.

     The rule is strict: used RAM must be below the threshold minus `rearmMarginPercent`.

     - Parameters:
       - usedPercent: Used RAM as a percentage of physical RAM.
       - thresholdPercent: The threshold. It is snapped to a slider stop first.
     - Returns: True when used RAM is below the re-arm line.
     */
    public static func rearms(usedPercent: Double, thresholdPercent: Int) -> Bool {
        let line = Double(AutoCleanThreshold.snapped(thresholdPercent) - rearmMarginPercent)
        return usedPercent < line
    }

    /**
     Returns the cooldown to use after a finished automatic clean.

     Freeing at least `effectiveFreedBytes` resets it to the floor. Any other result doubles it, up to
     `maxCooldownSeconds`. An unmeasured result is not proven effective, so it doubles too.

     - Parameters:
       - current: The current cooldown in seconds.
       - freedBytes: The bytes the clean freed, or nil when the change could not be measured.
     - Returns: The next cooldown in seconds.
     */
    public static func nextCooldown(current: Double, freedBytes: Int64?) -> Double {
        if let freed = freedBytes, freed >= effectiveFreedBytes { return cooldownSeconds }
        return min(current * 2, maxCooldownSeconds)
    }

    /**
     Reports whether the cooldown may return to its floor.

     True once used RAM has been continuously below the threshold for `cooldownResetBelowSeconds`.

     - Parameters:
       - belowSinceSeconds: The monotonic time the current dip began, or nil when used RAM is not below the threshold
         now.
       - monotonicNowSeconds: The current monotonic time in seconds.
     - Returns: True when the dip has lasted long enough.
     */
    public static func belowLongEnoughToResetCooldown(
        belowSinceSeconds: Double?, monotonicNowSeconds: Double
    ) -> Bool {
        guard let since = belowSinceSeconds else { return false }
        return monotonicNowSeconds - since >= cooldownResetBelowSeconds
    }

    /**
     Returns the first rule that stops a clean, or nil when a clean is due.

     The rules apply in this order: enabled, not paused, slot free, armed, at or above the threshold, sustained, and out
     of cooldown.

     - Parameter inputs: The readings for this tick.
     - Returns: The reason a clean is blocked, or nil.
     */
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

    /**
     Reports whether the cooldown after the last clean is still running.

     A future timestamp counts as in cooldown until the caller clamps and stores it. Clamping here would reset the
     window every tick.

     - Parameter inputs: The readings for this tick.
     - Returns: True while the cooldown is running.
     */
    static func inCooldown(_ inputs: AutoCleanInputs) -> Bool {
        guard let last = inputs.lastCleanAt else { return false }
        return last > inputs.nowEpoch || inputs.nowEpoch < last + inputs.cooldownSeconds
    }
}
