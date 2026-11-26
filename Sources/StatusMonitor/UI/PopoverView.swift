import AppKit
import StatusMonitorCore
import SwiftUI

/// The popover: one card per status bar item, each with its live value, its history and its details.
/// Configuration lives in the Settings window; each card's gear opens it.
struct PopoverView: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var monitor: MonitorViewModel
    /// When set, the popover shows only that status bar item's card. Nil shows every card.
    var only: MetricItemID? = nil
    let openSettings: () -> Void

    /// True when the card for this item should be drawn.
    private func shows(_ item: MetricItemID) -> Bool {
        only == nil || only == item
    }

    var body: some View {
        let s = settings.settings
        let caps = monitor.capabilities
        let rows = ReadoutBuilder.rows(for: monitor.snapshot, settings: s)
        let histories = monitor.histories

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header

                // CPU and RAM share one card: CPU % as the headline, with RAM's used memory and history alongside.
                if s.showCPU && shows(.cpu) {
                    MetricCard(
                        title: "CPU", symbol: MetricSymbol.cpu,
                        value: row("cpu", rows)?.value ?? "—",
                        accent: row("cpu", rows)?.accent,
                        series: series("cpu", histories, .cpu),
                        yDomain: 0...100,
                        stats: SeriesStatistics.of(histories[.cpu]?.values ?? []),
                        statFormat: { Format.percent($0) },
                        details: ramDetails(rows),
                        openSettings: openSettings
                    )
                }

                if caps.supports(.gpu), s.isCollectorEnabled(.gpu, capabilities: caps), shows(.gpu) {
                    MetricCard(
                        title: "GPU", symbol: MetricSymbol.gpu,
                        value: row("gpu", rows)?.value ?? "—",
                        accent: row("gpu", rows)?.accent,
                        series: series("gpu", histories, .gpu),
                        yDomain: 0...100,
                        stats: SeriesStatistics.of(histories[.gpu]?.values ?? []),
                        statFormat: { Format.percent($0) },
                        details: rowsFor(.gpu, rows).filter { $0.id == "vram" },
                        openSettings: openSettings
                    )
                }

                if caps.supports(.memoryPressure), s.isCollectorEnabled(.memoryPressure, capabilities: caps), shows(.memoryPressure),
                   let level = row("pressure", rows) {
                    MetricCard(
                        title: "Memory pressure", symbol: MetricSymbol.memoryPressure,
                        value: level.value, accent: level.accent,
                        series: [], yDomain: nil, stats: nil, statFormat: { "\($0)" },
                        details: [],
                        openSettings: openSettings
                    )
                }

                if s.showNetwork && shows(.network) {
                    NetworkCard(
                        down: Format.rate(monitor.snapshot.downBps),
                        up: Format.rate(monitor.snapshot.upBps),
                        downSeries: histories[.networkDown]?.values ?? [],
                        upSeries: histories[.networkUp]?.values ?? [],
                        downStats: SeriesStatistics.of(histories[.networkDown]?.values ?? []),
                        today: monitor.dailyTraffic,
                        openSettings: openSettings
                    )
                }

                if caps.supports(.disk), s.isCollectorEnabled(.disk, capabilities: caps), shows(.disk), monitor.snapshot.disk != nil {
                    MetricCard(
                        title: "Disk I/O", symbol: MetricSymbol.disk,
                        value: "↓ \(Format.rate(monitor.snapshot.disk?.readBps ?? 0))  ↑ \(Format.rate(monitor.snapshot.disk?.writeBps ?? 0))",
                        accent: nil,
                        series: [
                            ChartSeries(id: "read", values: histories[.diskRead]?.values ?? [], color: Brand.accent),
                            ChartSeries(id: "write", values: histories[.diskWrite]?.values ?? [], color: Brand.warm, dashed: true),
                        ],
                        yDomain: nil,
                        stats: SeriesStatistics.of(histories[.diskRead]?.values ?? []),
                        statFormat: { Format.rate($0) },
                        details: [],
                        openSettings: openSettings
                    )
                }

                if caps.supports(.battery), s.isCollectorEnabled(.battery, capabilities: caps), shows(.battery), monitor.snapshot.battery != nil {
                    MetricCard(
                        title: "Battery", symbol: MetricSymbol.battery(percent: 100, charging: false),
                        value: row("batt", rows)?.value ?? "—",
                        accent: nil,
                        series: [], yDomain: nil, stats: nil, statFormat: { "\($0)" },
                        details: rowsFor(.battery, rows).filter { $0.id != "batt" },
                        openSettings: openSettings
                    )
                }

                if caps.supports(.thermal), s.isCollectorEnabled(.thermal, capabilities: caps), shows(.thermal),
                   monitor.snapshot.thermal != nil {
                    MetricCard(
                        title: "Temperature & fans", symbol: MetricSymbol.thermal,
                        value: row("temp", rows)?.value ?? "—",
                        accent: row("temp", rows)?.accent,
                        series: series("temperature", histories, .temperature),
                        yDomain: nil,
                        stats: SeriesStatistics.of(histories[.temperature]?.values ?? []),
                        statFormat: { Format.celsius($0) },
                        details: rowsFor(.thermal, rows).filter { $0.id != "temp" },
                        openSettings: openSettings
                    )
                }

                footer
            }
            .padding(12)
            // Size to the cards, so the popover grows and shrinks with them.
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 360)
        .frame(maxHeight: only == nil ? 600 : 560)
        .preferredColorScheme(settings.settings.appearance.colorScheme)
    }

    /// Settings are opened from each card's gear icon, so the header carries only the title.
    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 20, height: 20)
            Text("StatusMonitor")
                .font(.headline)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Text("Refresh: 2 s open · 5 s closed")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func row(_ id: String, _ rows: [ReadoutRow]) -> ReadoutRow? {
        rows.first { $0.id == id }
    }

    /// RAM's used-memory line for the CPU card. It takes the RAM colour, so the threshold shows here too.
    private func ramDetails(_ rows: [ReadoutRow]) -> [ReadoutRow] {
        rows.filter { $0.id == "ram" }
    }

    private func rowsFor(_ collector: CollectorKind, _ rows: [ReadoutRow]) -> [ReadoutRow] {
        rows.filter { $0.collector == collector }
    }

    private func series(_ id: String, _ histories: [HistorySeries: SampleHistory], _ key: HistorySeries) -> [ChartSeries] {
        guard let values = histories[key]?.values, !values.isEmpty else { return [] }
        return [ChartSeries(id: id, values: values, color: Brand.accent)]
    }
}
