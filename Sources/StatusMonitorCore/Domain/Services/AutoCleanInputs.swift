import Foundation

/// The values one Auto Clean decision reads. Grouped so `AutoCleanDecision.evaluate` stays within the parameter limit.
public struct AutoCleanInputs: Equatable, Sendable {
    /// Whether the user turned Auto Clean on.
    public var enabled: Bool
    /// Used RAM as a percentage of physical RAM, 0...100.
    public var usedPercent: Double
    /// The user's threshold. Snapped to a slider stop before it is compared.
    public var thresholdPercent: Int
    /// Epoch seconds of the last clean, or nil when none has run.
    public var lastCleanAt: Double?
    /// The current time, in epoch seconds.
    public var nowEpoch: Double

    /// Re-arm state: false after a clean until RAM falls below threshold minus 5.
    public var armed = true
    /// True after three failed cleans in a row.
    public var paused = false
    /// True while a clean (automatic or manual) holds the shared slot.
    public var cleanInProgress = false
    /// The current cooldown, from the backoff rule.
    public var cooldownSeconds: Double = AutoCleanDecision.cooldownSeconds
    /// Monotonic seconds when used RAM last rose to the threshold. Nil while it is below.
    public var sustainStartSeconds: Double?
    /// Monotonic seconds now.
    public var monotonicNowSeconds: Double = 0

    /**
     Creates the inputs for one tick.

     The re-arm, pause, cooldown and sustain fields keep their defaults until the caller sets them.

     - Parameters:
       - enabled: Whether the user turned Auto Clean on.
       - usedPercent: Used RAM as a percentage of physical RAM, 0...100.
       - thresholdPercent: The user's threshold.
       - lastCleanAt: Epoch seconds of the last clean, or nil when none has run.
       - nowEpoch: The current time, in epoch seconds.
     */
    public init(
        enabled: Bool,
        usedPercent: Double,
        thresholdPercent: Int,
        lastCleanAt: Double?,
        nowEpoch: Double
    ) {
        self.enabled = enabled
        self.usedPercent = usedPercent
        self.thresholdPercent = thresholdPercent
        self.lastCleanAt = lastCleanAt
        self.nowEpoch = nowEpoch
    }
}
