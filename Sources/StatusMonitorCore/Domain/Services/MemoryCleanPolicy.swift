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
    public static let defaultPercent = 90
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

/// Decision for one Auto Clean tick. Pure, so the threshold, cooldown and skip reasons are testable without a timer.
public enum AutoCleanDecision: Equatable, Sendable {
    case clean
    case skip(reason: SkipReason)

    public enum SkipReason: String, Equatable, Sendable {
        case disabled = "auto clean is off"
        case belowThreshold = "RAM used below threshold"
        case cooldown = "cooldown"
        case helperNotAvailable = "helper not available"
    }

    /// Cooldown floor for Auto Clean. Not overridable.
    public static let cooldownSeconds: Double = 180

    /// - Parameter usedPercent: used RAM as a percentage of physical RAM, 0...100.
    public static func evaluate(
        enabled: Bool,
        usedPercent: Double,
        thresholdPercent: Int,
        lastCleanAt: Double?,
        // An autoclosure, so the helper check (which may spawn a process) runs only when a clean is otherwise due.
        helperAvailable: @autoclosure () -> Bool,
        nowEpoch: Double
    ) -> AutoCleanDecision {
        guard enabled else { return .skip(reason: .disabled) }
        guard usedPercent >= Double(AutoCleanThreshold.snapped(thresholdPercent)) else {
            return .skip(reason: .belowThreshold)
        }
        if let last = lastCleanAt {
            // A future timestamp is refused until the caller clamps and stores it. Clamping here would reset the window every tick.
            if last > nowEpoch || nowEpoch < last + cooldownSeconds {
                return .skip(reason: .cooldown)
            }
        }
        guard helperAvailable() else { return .skip(reason: .helperNotAvailable) }
        return .clean
    }
}
