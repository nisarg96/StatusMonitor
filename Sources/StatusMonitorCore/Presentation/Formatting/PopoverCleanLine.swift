import Foundation

/// The "Last clean freed X, N min ago" line under the Memory Clean buttons. Pure, so the wording is testable.
public enum PopoverCleanLine {
    /// Nil when there is no clean, or the latest one was skipped or could not be measured. The line is hidden then,
    /// never shown as zero.
    public static func text(latest: RecentClean?, now: Date) -> String? {
        guard let latest else { return nil }
        let freed = RecentCleanRows.freedLabel(latest.outcome)
        guard freed != "—" else { return nil }
        let minutes = max(0, Int(now.timeIntervalSince(latest.date) / 60))
        return "Last clean freed \(freed), \(minutes) min ago"
    }
}
