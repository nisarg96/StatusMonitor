import AppKit
import StatusMonitorCore
import SwiftUI

/**
 The menu bar popover, 380 pt wide.

 It has a header, one card per metric in the design's order, Memory Clean, Open at login, and a footer. A metric the
 Mac cannot provide has no card. A metric that is switched off keeps its header so it can be switched back on. The
 status bar item's own popover shows only that item's card.
 */
struct PopoverView: View {
    /// The settings that decide which cards show and their values.
    @ObservedObject var settings: SettingsViewModel
    /// The monitor that supplies the snapshot, the histories and the capabilities.
    @ObservedObject var monitor: MonitorViewModel
    /// When set, the popover shows only that status bar item's card. Nil shows every card.
    var only: MetricItemID?
    /// Opens the Settings window.
    let openSettings: () -> Void
    /// Memory Clean. Nil leaves the clean buttons disabled until the app passes the view model in.
    var memoryClean: MemoryCleanViewModel?
    /// The speed test shown on the Network card. Nil hides its controls.
    var speedTest: SpeedTestViewModel?

    /// Real physical RAM, so the RAM total is never a sample value.
    private let physicalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory

    var body: some View {
        let metrics = settings.settings
        let caps = monitor.capabilities
        let rows = ReadoutBuilder.rows(for: monitor.snapshot, settings: metrics)

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                cpuSection(metrics)
                gpuSection(metrics, caps)
                pressureSection(metrics, caps, rows)
                diskSection(metrics, caps)
                batterySection(metrics, caps, rows)
                thermalSection(metrics, caps, rows)
                networkSection(metrics)
                if only == nil {
                    cleanSection(metrics)
                    PopoverLoginRow(
                        opensAtLogin: settings.opensAtLogin,
                        errorText: settings.loginItemError,
                        onChange: { settings.setOpensAtLogin($0) }
                    )
                }
                footer
            }
            .padding(16)
            .frame(width: 380)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 380)
        .frame(maxHeight: only == nil ? 600 : 560)
        .background(PopoverPalette.ground)
        .preferredColorScheme(metrics.appearance.colorScheme)
    }

    // MARK: - Header and footer

    private var header: some View {
        HStack {
            Text("StatusMonitor")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PopoverPalette.text)
            Spacer(minLength: 8)
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(PopoverPalette.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…", action: openSettings)
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(PopoverPalette.accent)
            Spacer(minLength: 8)
            Button("Quit StatusMonitor") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(PopoverPalette.accent)
                .keyboardShortcut("q")
        }
        .padding(.top, 2)
    }

    // MARK: - Sections

    private func shows(_ item: MetricItemID) -> Bool {
        only == nil || only == item
    }

    private func enabled(_ kind: CollectorKind, _ caps: MetricCapabilities, _ metrics: MetricSettings) -> Bool {
        metrics.isCollectorEnabled(kind, capabilities: caps)
    }

    @ViewBuilder
    private func cpuSection(_ metrics: MetricSettings) -> some View {
        if shows(.cpu) {
            if monitor.snapshot.isSampled {
                PopoverCPUSection(
                    snapshot: monitor.snapshot,
                    settings: metrics,
                    physicalBytes: physicalBytes,
                    history: monitor.timedHistories[.cpu] ?? TimedSampleHistory(),
                    onToggle: { settings.setShowCPU($0) }
                )
            } else {
                placeholderCard("CPU and memory", ids: ["cpu", "ram"], metrics: metrics,
                                shown: metrics.showCPU, onToggle: { settings.setShowCPU($0) })
            }
        }
    }

    /// Before the first sample, a card keeps its header and shows its readout rows as "--", with no chart.
    private func placeholderCard(
        _ title: String, ids: [String], metrics: MetricSettings, shown: Bool, onToggle: @escaping (Bool) -> Void
    ) -> some View {
        let rows = ReadoutBuilder.rows(for: monitor.snapshot, settings: metrics)
        return PopoverMetricSection(
            title: title, shown: shown, onToggle: onToggle,
            lines: rows.filter { ids.contains($0.id) }.map { makeLine($0) }
        )
    }

    /// GPU has a card only where the Mac reports GPU load.
    @ViewBuilder
    private func gpuSection(_ metrics: MetricSettings, _ caps: MetricCapabilities) -> some View {
        if caps.supports(.gpu), shows(.gpu) {
            let utilization = monitor.snapshot.gpu?.utilizationPercent
            PopoverMetricSection(
                title: "GPU",
                shown: enabled(.gpu, caps, metrics),
                onToggle: { settings.setCollectorEnabled(.gpu, $0) },
                lines: utilization.map { percent in
                    [PopoverMetricSection.Line(
                        id: "gpu", label: "Utilisation", value: Format.percent(percent), bar: percent / 100
                    )]
                } ?? []
            )
        }
    }

    @ViewBuilder
    private func pressureSection(
        _ metrics: MetricSettings, _ caps: MetricCapabilities, _ rows: [ReadoutRow]
    ) -> some View {
        if caps.supports(.memoryPressure), shows(.memoryPressure) {
            PopoverMetricSection(
                title: "Memory pressure",
                shown: enabled(.memoryPressure, caps, metrics),
                onToggle: { settings.setCollectorEnabled(.memoryPressure, $0) },
                lines: rows.filter { $0.id == "pressure" }.map { makeLine($0, label: "State") }
            )
        }
    }

    @ViewBuilder
    private func networkSection(_ metrics: MetricSettings) -> some View {
        if shows(.network) {
            if monitor.snapshot.isSampled {
                PopoverNetworkSection(
                    upBps: monitor.snapshot.upBps,
                    downBps: monitor.snapshot.downBps,
                    upHistory: monitor.timedHistories[.networkUp] ?? TimedSampleHistory(),
                    downHistory: monitor.timedHistories[.networkDown] ?? TimedSampleHistory(),
                    today: monitor.dailyTraffic,
                    directions: NetworkDirection.shown(in: metrics),
                    shown: metrics.showNetwork,
                    onToggle: { settings.setShowNetwork($0) },
                    speedTest: speedTest
                )
            } else {
                placeholderCard("Network", ids: ["down", "up"], metrics: metrics,
                                shown: metrics.showNetwork, onToggle: { settings.setShowNetwork($0) })
            }
        }
    }

    @ViewBuilder
    private func diskSection(_ metrics: MetricSettings, _ caps: MetricCapabilities) -> some View {
        if caps.supports(.disk), shows(.disk) {
            PopoverDiskSection(
                disk: monitor.snapshot.disk,
                read: monitor.timedHistories[.diskRead] ?? TimedSampleHistory(),
                write: monitor.timedHistories[.diskWrite] ?? TimedSampleHistory(),
                shown: enabled(.disk, caps, metrics),
                onToggle: { settings.setCollectorEnabled(.disk, $0) }
            )
        }
    }

    @ViewBuilder
    private func batterySection(
        _ metrics: MetricSettings, _ caps: MetricCapabilities, _ rows: [ReadoutRow]
    ) -> some View {
        if caps.supports(.battery), shows(.battery) {
            PopoverMetricSection(
                title: "Battery",
                shown: enabled(.battery, caps, metrics),
                onToggle: { settings.setCollectorEnabled(.battery, $0) },
                lines: batteryLines(rows)
            )
        }
    }

    @ViewBuilder
    private func thermalSection(
        _ metrics: MetricSettings, _ caps: MetricCapabilities, _ rows: [ReadoutRow]
    ) -> some View {
        if caps.supports(.thermal), shows(.thermal) {
            PopoverMetricSection(
                title: "Thermal",
                shown: enabled(.thermal, caps, metrics),
                onToggle: { settings.setCollectorEnabled(.thermal, $0) },
                lines: rows.filter { $0.id == "temp" }.map { makeLine($0, label: "CPU") }
            )
        }
    }

    @ViewBuilder
    private func cleanSection(_ metrics: MetricSettings) -> some View {
        if let memoryClean {
            PopoverCleanObserver(
                clean: memoryClean,
                autoCleanOn: metrics.autoCleanEnabled,
                thresholdPercent: metrics.autoCleanThresholdPercent,
                onAutoClean: { settings.setAutoCleanEnabled($0) }
            )
        } else {
            PopoverCleanSection(
                autoCleanOn: metrics.autoCleanEnabled,
                thresholdPercent: metrics.autoCleanThresholdPercent,
                canClean: false,
                isCleaning: false,
                lastLine: nil,
                onClean: { _ in },
                onAutoClean: { settings.setAutoCleanEnabled($0) }
            )
        }
    }

    // MARK: - Rows

    /**
     Converts a readout row into a popover row.

     - Parameter row: The readout row to convert.
     - Parameter label: A label that replaces the row's own label, or nil to keep it.
     - Returns: The popover row, with its accent colour.
     */
    private func makeLine(_ row: ReadoutRow, label: String? = nil) -> PopoverMetricSection.Line {
        PopoverMetricSection.Line(
            id: row.id,
            label: label ?? row.label,
            value: row.value,
            accent: PopoverPalette.color(for: row.accent)
        )
    }

    /**
     Builds the battery rows from the readout, without the power-flow line. The charge row gets a bar.

     - Parameter rows: The readout rows to filter.
     - Returns: The battery rows, in order.
     */
    private func batteryLines(_ rows: [ReadoutRow]) -> [PopoverMetricSection.Line] {
        let percent = monitor.snapshot.battery?.currentPercent
        return rows.filter { $0.collector == .battery && $0.id != "flow" }.map { row in
            var line = makeLine(row)
            if row.id == "batt", let percent {
                line.bar = Double(percent) / 100
            }
            return line
        }
    }
}
