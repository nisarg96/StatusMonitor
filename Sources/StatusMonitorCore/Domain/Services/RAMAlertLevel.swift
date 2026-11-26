import Foundation

/**
 Colour state for used RAM, driven by the RAM threshold that also triggers Auto Clean.

 Red at or above the threshold, orange within 10 points below it, normal otherwise.
 */
public enum RAMAlertLevel {
    /// The width of the warning band below the threshold, in percentage points.
    public static let warningBandPoints = 10.0

    /**
     Returns used RAM as a percentage of physical RAM.

     - Parameters:
       - usedBytes: Used RAM in bytes.
       - physicalBytes: Total physical RAM in bytes.
     - Returns: The percentage, or nil when `physicalBytes` is zero.
     */
    public static func usedPercent(usedBytes: UInt64, physicalBytes: UInt64) -> Double? {
        guard physicalBytes > 0 else { return nil }
        return Double(usedBytes) / Double(physicalBytes) * 100
    }

    /**
     Returns the alert state for used RAM.

     - Parameters:
       - usedPercent: Used RAM as a percentage of physical RAM.
       - thresholdPercent: The Auto Clean threshold. It is snapped to a slider stop first.
     - Returns: `.critical` at or above the threshold, `.warning` within `warningBandPoints` below it, and `.normal`
       otherwise.
     */
    public static func level(usedPercent: Double, thresholdPercent: Int) -> ReadoutAccent {
        let threshold = Double(AutoCleanThreshold.snapped(thresholdPercent))
        if usedPercent >= threshold { return .critical }
        if usedPercent >= threshold - warningBandPoints { return .warning }
        return .normal
    }
}
