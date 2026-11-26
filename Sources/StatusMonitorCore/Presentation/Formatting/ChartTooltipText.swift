import Foundation

/// Value text for chart tooltips. Uses the same units as the readouts, so a tooltip and its card never disagree.
public enum ChartTooltipText {
    /// "↑ 1.2 MB/s" then "↓ 340.0 KB/s".
    public static func network(upBps: Double, downBps: Double) -> [String] {
        ["↑ \(Format.rate(upBps))", "↓ \(Format.rate(downBps))"]
    }

    /// "↓ 2.0 KB/s" for reads, then "↑ 0 B/s" for writes.
    public static func disk(readBps: Double, writeBps: Double) -> [String] {
        ["↓ \(Format.rate(readBps))", "↑ \(Format.rate(writeBps))"]
    }

    /// "CPU 12%".
    public static func cpu(percent: Double) -> [String] {
        ["CPU \(Format.percent(percent))"]
    }
}
