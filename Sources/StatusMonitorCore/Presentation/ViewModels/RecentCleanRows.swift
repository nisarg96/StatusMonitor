import Foundation

/**
 One finished clean and when it ran.

 `CleanOutcome` has no time of its own, so the caller supplies it.
 */
public struct RecentClean: Equatable, Sendable {
    /// When the clean ran.
    public let date: Date
    /// What the clean freed, or why it was skipped.
    public let outcome: CleanOutcome

    /**
     Creates a recent clean from its time and outcome.

     - Parameters:
       - date: When the clean ran.
       - outcome: What the clean freed, or why it was skipped.
     */
    public init(date: Date, outcome: CleanOutcome) {
        self.date = date
        self.outcome = outcome
    }
}

/// One row of the recent-cleans list, with every cell ready to show.
public struct RecentCleanRow: Equatable, Sendable {
    /// The formatted time the clean ran.
    public let time: String
    /// The preset name, such as "Standard".
    public let type: String
    /// The formatted memory freed, or a dash when the clean was skipped or not measured.
    public let freed: String

    /**
     Creates a row from its formatted cells.

     - Parameters:
       - time: The formatted time the clean ran.
       - type: The preset name.
       - freed: The formatted memory freed.
     */
    public init(time: String, type: String, freed: String) {
        self.time = time
        self.type = type
        self.freed = freed
    }
}

/// Builds the rows for the recent-cleans list.
public enum RecentCleanRows {
    private static let bytesPerMiB = 1024.0 * 1024
    private static let bytesPerGiB = 1024.0 * 1024 * 1024

    /**
     Builds one row per clean, in the order given.

     Pass newest first to show the newest clean at the top.

     - Parameters:
       - cleans: The cleans to show.
       - time: Formats a clean's date for the time cell.
     - Returns: One row per clean, in the same order.
     */
    public static func rows(_ cleans: [RecentClean], time: (Date) -> String) -> [RecentCleanRow] {
        cleans.map { clean in
            RecentCleanRow(
                time: time(clean.date),
                type: typeLabel(clean.outcome.preset),
                freed: freedLabel(clean.outcome)
            )
        }
    }

    /**
     Returns the display name for a clean preset.

     - Parameters:
       - preset: The clean preset.
     - Returns: "Standard" or "Extreme".
     */
    public static func typeLabel(_ preset: CleanPreset) -> String {
        switch preset {
        case .standard: return "Standard"
        case .extreme: return "Extreme"
        }
    }

    /**
     Returns the memory a clean freed, formatted in GB or MB.

     Skipped or unmeasured cleans show a dash. A negative change shows as zero. GB here is GiB.

     - Parameters:
       - outcome: The clean's outcome.
     - Returns: A string such as "1.2 GB", "512 MB", or "—" for a dash.
     */
    public static func freedLabel(_ outcome: CleanOutcome) -> String {
        guard outcome.skippedReason == nil, let delta = outcome.totalDeltaBytes else { return "—" }
        let bytes = Double(max(0, delta))
        if bytes >= bytesPerGiB {
            return String(format: "%.1f GB", bytes / bytesPerGiB)
        }
        return String(format: "%.0f MB", bytes / bytesPerMiB)
    }
}
