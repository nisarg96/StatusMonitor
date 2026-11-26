import Foundation

/**
 Formats speed test results for display. A measurement that was not taken shows "--", never zero.

 Rates are decimal Mbit/s, as the speed test reports them.
 */
public enum SpeedTestFormat {
    /// The text for a measurement that was not taken.
    public static let placeholder = "--"

    /// The text for packet loss, which the speed test does not measure yet.
    public static let packetLossNotMeasured = "not measured"

    /**
     Formats a rate in decimal Mbit/s.

     - Parameter mbps: The rate, or nil when it was not measured.
     - Returns: For example "80.0 Mbit/s", or "--" for nil.
     */
    public static func rate(_ mbps: Double?) -> String {
        guard let mbps else { return placeholder }
        return String(format: "%.1f Mbit/s", mbps)
    }

    /**
     Formats a latency or jitter in milliseconds.

     - Parameter milliseconds: The duration, or nil when it was not measured.
     - Returns: For example "12.3 ms", or "--" for nil.
     */
    public static func milliseconds(_ milliseconds: Double?) -> String {
        guard let milliseconds else { return placeholder }
        return String(format: "%.1f ms", milliseconds)
    }

    /**
     Lists a result's measurements in display order: download, upload, latency, jitter and packet loss.

     - Parameter result: The result to list.
     - Returns: Five rows. Unmeasured values show "--", and unmeasured packet loss shows "not measured".
     */
    public static func rows(for result: SpeedTestResult) -> [SpeedTestRow] {
        let loss = result.packetLossPercent.map { String(format: "%.1f%%", $0) } ?? packetLossNotMeasured
        return [
            SpeedTestRow(label: "Download", value: rate(result.downloadMbps)),
            SpeedTestRow(label: "Upload", value: rate(result.uploadMbps)),
            SpeedTestRow(label: "Latency", value: milliseconds(result.latencyMs)),
            SpeedTestRow(label: "Jitter", value: milliseconds(result.jitterMs)),
            SpeedTestRow(label: "Packet loss", value: loss)
        ]
    }
}
