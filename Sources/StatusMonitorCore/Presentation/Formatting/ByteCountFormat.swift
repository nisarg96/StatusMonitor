import Foundation

/**
 Formats byte totals, such as today's traffic, for display.

 Uses 1024 steps like `Format.rate`, so small totals show in KB or MB.
 */
public enum ByteCountFormat {
    /**
     Formats a byte count as a short total for display.

     Negative input shows as zero.

     - Parameters:
       - bytes: The byte count.
     - Returns: A string such as "512 B", "340.0 KB", "1.5 MB" or "3.0 GB".
     */
    public static func text(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(0, bytes)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let number = index == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(number) \(units[index])"
    }
}
