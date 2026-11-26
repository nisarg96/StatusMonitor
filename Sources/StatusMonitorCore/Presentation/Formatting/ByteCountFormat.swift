import Foundation

/// Byte totals such as today's traffic. Uses 1024 steps like `Format.rate`, so small totals show in KB or MB.
public enum ByteCountFormat {
    /// "512 B", "340.0 KB", "1.5 MB", "3.0 GB". Negative input shows as zero.
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
