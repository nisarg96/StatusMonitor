@testable import StatusMonitorCore

/// Shared fixtures for the glyph characterization suites. Calls use 8 GiB of physical memory unless told otherwise.
let characterizationPhysicalBytes: UInt64 = 8 * 1_073_741_824

/// Builds the glyph for an item with the given config, as MenuBarGlyphBuilder would.
func glyphOf(
    _ item: MetricItemID,
    _ snapshot: SystemSnapshot = SystemSnapshot(),
    style: MenuBarItemStyle? = nil,
    alertAbove: Double? = nil,
    history: [HistorySeries: SampleHistory] = [:],
    physicalBytes: UInt64? = nil,
    // Pinned at 90 so these glyph characterizations do not move when the Auto Clean default changes.
    threshold: Int = 90,
    cpuMode: CPUDisplayMode = .percent
) -> MenuBarGlyph? {
    var config = MenuBarItemConfig.defaults(for: item)
    if let style { config.style = style }
    config.alertAbove = alertAbove
    return MenuBarGlyphBuilder.glyph(
        for: item, snapshot: snapshot, config: config, history: history,
        physicalMemoryBytes: physicalBytes ?? characterizationPhysicalBytes,
        ramThresholdPercent: threshold, cpuMode: cpuMode
    )
}

/// A history holding the given values, oldest first, for one series.
func historyOf(_ series: HistorySeries, _ values: [Double]) -> [HistorySeries: SampleHistory] {
    var sample = SampleHistory()
    for value in values { sample.append(value) }
    return [series: sample]
}
