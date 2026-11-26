import Foundation

/**
 Formats the "Last clean" line shown under the Memory Clean buttons.

 Pure, so the wording is testable.
 */
public enum PopoverCleanLine {
    /**
     Returns the "Last clean" line for the latest clean, or nil when there is none to show.

     Nil when there is no clean, or the latest one was skipped or could not be measured. The line is hidden then,
     never shown as zero.

     - Parameters:
       - latest: The most recent clean, or nil when no clean has run.
       - now: The current time, used to count the minutes since the clean.
     - Returns: A line such as "Last clean freed 512 MB, 3 min ago", or nil.
     */
    public static func text(latest: RecentClean?, now: Date) -> String? {
        guard let latest else { return nil }
        let freed = RecentCleanRows.freedLabel(latest.outcome)
        guard freed != "—" else { return nil }
        let minutes = max(0, Int(now.timeIntervalSince(latest.date) / 60))
        return "Last clean freed \(freed), \(minutes) min ago"
    }
}
