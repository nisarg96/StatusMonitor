import Foundation

/**
 Numbers and sentences for the Memory Clean page's threshold line.

 Pure, so the arithmetic is testable. GB here is GiB (1024³ bytes), matching `Format.gib`.
 */
public enum MemoryCleanSummary {
    private static let bytesPerGiB = 1_073_741_824.0

    /**
     Returns the free memory left when used RAM reaches the threshold.

     Computed as physical × (100 − threshold) / 100. The threshold is snapped to a slider stop first.

     - Parameters:
       - thresholdPercent: The Auto Clean threshold, in percent of physical RAM.
       - physicalBytes: Physical RAM, in bytes.
     - Returns: The free memory, in GiB.
     */
    public static func freeGiB(thresholdPercent: Int, physicalBytes: UInt64) -> Double {
        let percent = Double(AutoCleanThreshold.snapped(thresholdPercent))
        return Double(physicalBytes) * (100 - percent) / 100 / bytesPerGiB
    }

    /**
     Returns total physical memory in GiB.

     - Parameters:
       - physicalBytes: Physical RAM, in bytes.
     - Returns: The total, in GiB.
     */
    public static func totalGiB(physicalBytes: UInt64) -> Double {
        Double(physicalBytes) / bytesPerGiB
    }

    /**
     Returns the threshold sentence shown on the Memory Clean page.

     - Parameters:
       - thresholdPercent: The Auto Clean threshold, in percent of physical RAM.
       - physicalBytes: Physical RAM, in bytes.
     - Returns: A sentence such as "Clean when RAM in use reaches 85%, about 2.4 GB free of 16.0 GB."
     */
    public static func sentence(thresholdPercent: Int, physicalBytes: UInt64) -> String {
        let percent = AutoCleanThreshold.snapped(thresholdPercent)
        let free = String(format: "%.1f", freeGiB(thresholdPercent: percent, physicalBytes: physicalBytes))
        let total = String(format: "%.1f", totalGiB(physicalBytes: physicalBytes))
        return "Clean when RAM in use reaches \(percent)%, about \(free) GB free of \(total) GB."
    }

    /// The minimum wait between Auto Cleans, read from the policy, e.g. "3 minutes".
    public static var cooldownText: String {
        let minutes = Int(AutoCleanDecision.cooldownSeconds / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}
