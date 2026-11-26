import Foundation

/// Summary of a recent history, shown under each card. Nil when there are no samples, never zero.
public struct SeriesStatistics: Equatable, Sendable {
    /// The smallest value in the series.
    public let minimum: Double
    /// The largest value in the series.
    public let maximum: Double
    /// The mean of the values in the series.
    public let average: Double
    /// The most recent value in the series.
    public let latest: Double

    /**
     Creates a summary from values that are already computed.

     - Parameters:
       - minimum: The smallest value.
       - maximum: The largest value.
       - average: The mean of the values.
       - latest: The most recent value.
     */
    public init(minimum: Double, maximum: Double, average: Double, latest: Double) {
        self.minimum = minimum
        self.maximum = maximum
        self.average = average
        self.latest = latest
    }

    /**
     Summarizes a series of values.

     - Parameter values: The values to summarize, oldest first. The last value is the latest.
     - Returns: The summary, or nil when `values` is empty.
     */
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
    /// Bytes received on `day`.
    public var downBytes: Double
    /// Bytes sent on `day`.
    public var upBytes: Double

    /**
     Creates a day's totals.

     - Parameters:
       - day: The local calendar day, "yyyy-MM-dd".
       - downBytes: Bytes received on the day. Defaults to 0.
       - upBytes: Bytes sent on the day. Defaults to 0.
     */
    public init(day: String, downBytes: Double = 0, upBytes: Double = 0) {
        self.day = day
        self.downBytes = downBytes
        self.upBytes = upBytes
    }

    /**
     Adds one interval's traffic to the day's total.

     A new day starts a fresh total, so yesterday never bleeds into today. Negative rates count as 0. Nothing is added
     when `seconds` is 0 or less.

     - Parameters:
       - current: The running total, or nil when there is none yet.
       - day: The local day key for this interval, "yyyy-MM-dd".
       - downBytesPerSecond: The download rate over the interval, in bytes per second.
       - upBytesPerSecond: The upload rate over the interval, in bytes per second.
       - seconds: The length of the interval in seconds.
     - Returns: The updated total for `day`.
     */
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

    /**
     Returns the local day key for a date.

     - Parameters:
       - date: The date to format.
       - calendar: The calendar that defines the local day. Defaults to the current calendar.
     - Returns: The day as "yyyy-MM-dd", for example "2026-11-26".
     */
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
