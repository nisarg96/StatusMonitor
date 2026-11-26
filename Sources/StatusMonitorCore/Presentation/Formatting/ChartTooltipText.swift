import Foundation

/**
 Builds the value text for chart tooltips.

 Uses the same units as the readouts, so a tooltip and its card never disagree.
 */
public enum ChartTooltipText {
    /**
     Builds the tooltip values for network throughput.

     - Parameters:
       - upBps: The upload rate, in bytes per second.
       - downBps: The download rate, in bytes per second.
     - Returns: Two strings: the upload, then the download, such as "↑ 1.2 MB/s" then "↓ 340.0 KB/s".
     */
    public static func network(upBps: Double, downBps: Double) -> [String] {
        ["↑ \(Format.rate(upBps))", "↓ \(Format.rate(downBps))"]
    }

    /**
     Builds the tooltip values for disk I/O.

     - Parameters:
       - readBps: The read rate, in bytes per second.
       - writeBps: The write rate, in bytes per second.
     - Returns: Two strings: the read, then the write, such as "↓ 2.0 KB/s" then "↑ 0 B/s".
     */
    public static func disk(readBps: Double, writeBps: Double) -> [String] {
        ["↓ \(Format.rate(readBps))", "↑ \(Format.rate(writeBps))"]
    }

    /**
     Builds the tooltip value for CPU load.

     - Parameters:
       - percent: The CPU load, in percent. Clamped to 0...100 by `Format.percent`.
     - Returns: One string, such as "CPU 12%".
     */
    public static func cpu(percent: Double) -> [String] {
        ["CPU \(Format.percent(percent))"]
    }
}
