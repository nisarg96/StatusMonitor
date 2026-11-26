import Foundation

/// One finished clean and when it ran. `CleanOutcome` has no time of its own, so the caller supplies it.
public struct RecentClean: Equatable, Sendable {
    public let date: Date
    public let outcome: CleanOutcome

    public init(date: Date, outcome: CleanOutcome) {
        self.date = date
        self.outcome = outcome
    }
}

/// One row of the recent-cleans list, with every cell ready to show.
public struct RecentCleanRow: Equatable, Sendable {
    public let time: String
    public let type: String
    public let freed: String

    public init(time: String, type: String, freed: String) {
        self.time = time
        self.type = type
        self.freed = freed
    }
}

public enum RecentCleanRows {
    private static let bytesPerMiB = 1024.0 * 1024
    private static let bytesPerGiB = 1024.0 * 1024 * 1024

    /// Rows in the order given, newest first when the caller passes newest first.
    public static func rows(_ cleans: [RecentClean], time: (Date) -> String) -> [RecentCleanRow] {
        cleans.map { clean in
            RecentCleanRow(
                time: time(clean.date),
                type: typeLabel(clean.outcome.preset),
                freed: freedLabel(clean.outcome)
            )
        }
    }

    public static func typeLabel(_ preset: CleanPreset) -> String {
        switch preset {
        case .standard: return "Standard"
        case .extreme: return "Extreme"
        }
    }

    /// The memory a clean freed. Skipped or unmeasured cleans show a dash. A negative delta shows as zero.
    public static func freedLabel(_ outcome: CleanOutcome) -> String {
        guard outcome.skippedReason == nil, let delta = outcome.totalDeltaBytes else { return "—" }
        let bytes = Double(max(0, delta))
        if bytes >= bytesPerGiB {
            return String(format: "%.1f GB", bytes / bytesPerGiB)
        }
        return String(format: "%.0f MB", bytes / bytesPerMiB)
    }
}
