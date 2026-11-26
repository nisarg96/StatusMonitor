import Foundation

/// Colour state for used RAM, driven by the RAM threshold that also triggers Auto Clean.
/// Red at or above the threshold, orange within 10 points below it, normal otherwise.
public enum RAMAlertLevel {
    public static let warningBandPoints = 10.0

    public static func usedPercent(usedBytes: UInt64, physicalBytes: UInt64) -> Double? {
        guard physicalBytes > 0 else { return nil }
        return Double(usedBytes) / Double(physicalBytes) * 100
    }

    public static func level(usedPercent: Double, thresholdPercent: Int) -> ReadoutAccent {
        let threshold = Double(AutoCleanThreshold.snapped(thresholdPercent))
        if usedPercent >= threshold { return .critical }
        if usedPercent >= threshold - warningBandPoints { return .warning }
        return .normal
    }
}
