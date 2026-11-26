import Foundation

/// Summary of a recent history, shown under each card. Nil when there are no samples, never zero.
public struct SeriesStatistics: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let average: Double
    public let latest: Double

    public init(minimum: Double, maximum: Double, average: Double, latest: Double) {
        self.minimum = minimum
        self.maximum = maximum
        self.average = average
        self.latest = latest
    }

    public static func of(_ values: [Double]) -> SeriesStatistics? {
        guard let first = values.first, let last = values.last else { return nil }
        var low = first
        var high = first
        var total = 0.0
        for value in values {
            low = min(low, value)
            high = max(high, value)
            total += value
        }
        return SeriesStatistics(
            minimum: low,
            maximum: high,
            average: total / Double(values.count),
            latest: last
        )
    }
}

/// Per-day network totals, so the popover can show "today" in a meaningful way.
public struct DailyTraffic: Equatable, Codable, Sendable {
    /// Local calendar day, "yyyy-MM-dd".
    public var day: String
    public var downBytes: Double
    public var upBytes: Double

    public init(day: String, downBytes: Double = 0, upBytes: Double = 0) {
        self.day = day
        self.downBytes = downBytes
        self.upBytes = upBytes
    }

    /// Adds one interval's traffic. A new day starts a fresh total, so yesterday never bleeds into today.
    public static func accumulate(
        into current: DailyTraffic?,
        day: String,
        downBytesPerSecond: Double,
        upBytesPerSecond: Double,
        seconds: Double
    ) -> DailyTraffic {
        guard seconds > 0 else { return current ?? DailyTraffic(day: day) }
        var next = (current?.day == day) ? (current ?? DailyTraffic(day: day)) : DailyTraffic(day: day)
        next.downBytes += max(0, downBytesPerSecond) * seconds
        next.upBytes += max(0, upBytesPerSecond) * seconds
        return next
    }

    /// The local day key for a date, for example "2026-11-26".
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
