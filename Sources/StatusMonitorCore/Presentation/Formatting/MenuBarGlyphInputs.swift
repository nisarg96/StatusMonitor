import Foundation

/// Everything a menu bar renderer may read, bundled so each renderer takes one argument.
struct MenuBarGlyphInputs: Sendable {
    /// The latest system snapshot.
    let snapshot: SystemSnapshot
    /// The item's appearance and alert settings.
    let config: MenuBarItemConfig
    /// Recent samples per series, used by the sparkline and bar styles.
    let history: [HistorySeries: SampleHistory]
    /// Physical RAM in bytes. Zero when unknown.
    let physicalMemoryBytes: UInt64
    /// The RAM alert threshold, in percent of physical RAM.
    let ramThresholdPercent: Int
    /// How the CPU item is shown: CPU percent, or used RAM in GB.
    let cpuMode: CPUDisplayMode
    /// The network directions that are shown. The network item draws only these.
    let networkDirections: [NetworkDirection]

    /// The item's display style.
    var style: MenuBarItemStyle { config.style }

    /**
     Returns whether a value is above the item's alert threshold.

     Alerts apply only when the user set a threshold for the item.

     - Parameters:
       - value: The value, in the item's own unit.
     - Returns: True when the item has a threshold and `value` is above it.
     */
    func isAlert(_ value: Double) -> Bool {
        guard let threshold = config.alertAbove else { return false }
        return value > threshold
    }

    /// Used RAM as a percentage of physical RAM. Nil until the Mac's physical memory is known.
    var ramUsedPercent: Double? {
        guard physicalMemoryBytes > 0 else { return nil }
        return Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100
    }

    /**
     Maps a history series to values scaled to 0...1.

     Percent series use a fixed 0...100 scale. Rate series scale to their own peak, so a quiet network still shows
     its shape. Empty history gives no levels.

     - Parameters:
       - series: The series to read.
       - percentScale: True to scale from 0...100. False to scale to the series' own peak.
     - Returns: One level per sample, oldest first.
     */
    func levels(_ series: HistorySeries, percentScale: Bool) -> [Double] {
        guard let values = history[series]?.values, !values.isEmpty else { return [] }
        if percentScale {
            return values.map { min(1, max(0, $0 / 100)) }
        }
        let peak = values.max() ?? 0
        guard peak > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / peak }
    }
}
