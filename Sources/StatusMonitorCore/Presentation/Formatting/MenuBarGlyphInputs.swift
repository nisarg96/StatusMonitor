import Foundation

/// Everything a menu bar renderer may read, bundled so each renderer takes one argument.
struct MenuBarGlyphInputs: Sendable {
    let snapshot: SystemSnapshot
    let config: MenuBarItemConfig
    let history: [HistorySeries: SampleHistory]
    let physicalMemoryBytes: UInt64
    let ramThresholdPercent: Int
    let cpuMode: CPUDisplayMode

    var style: MenuBarItemStyle { config.style }

    /// Alerts apply only when the user set a threshold for the item.
    func isAlert(_ value: Double) -> Bool {
        guard let threshold = config.alertAbove else { return false }
        return value > threshold
    }

    /// Used RAM as a percentage of physical RAM. Nil until the Mac's physical memory is known.
    var ramUsedPercent: Double? {
        guard physicalMemoryBytes > 0 else { return nil }
        return Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100
    }

    /// Maps a series to 0...1. Percent series use a fixed 0...100 scale; rate series scale to their own peak,
    /// so a quiet network still shows its shape. Empty history gives no levels.
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
