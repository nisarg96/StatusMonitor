import StatusMonitorCore
import SwiftUI

/// CPU and memory: CPU percent with a bar, used RAM as "used of total" with a bar, and the hoverable CPU chart.
/// The total is the Mac's real physical RAM, so it is never a guess.
struct PopoverCPUSection: View {
    let snapshot: SystemSnapshot
    let settings: MetricSettings
    let physicalBytes: UInt64
    let history: TimedSampleHistory
    let onToggle: (Bool) -> Void

    var body: some View {
        PopoverSectionCard(title: "CPU and memory", shown: settings.showCPU, onToggle: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                PopoverValueRow(label: "CPU", value: Format.percent(snapshot.cpuPercent))
                PopoverBar(fraction: snapshot.cpuPercent / 100)
                if physicalBytes > 0 {
                    PopoverValueRow(
                        label: "RAM",
                        value: "\(Format.gib(snapshot.memoryUsedBytes)) of \(Format.gib(physicalBytes))",
                        accent: PopoverPalette.color(for: ramAccent)
                    )
                    PopoverBar(
                        fraction: Double(snapshot.memoryUsedBytes) / Double(physicalBytes),
                        fill: PopoverPalette.color(for: ramAccent)
                    )
                }
                if !history.samples.isEmpty {
                    ChartHoverChart(
                        lines: [ChartLine(id: "cpu", history: history, color: PopoverPalette.fill)],
                        yDomain: 0...100,
                        tooltip: { index in
                            history.value(at: index).map { ChartTooltipText.cpu(percent: $0) } ?? []
                        }
                    )
                }
            }
        }
    }

    /// The RAM colour from the readout rules: orange or red as used RAM nears the Auto Clean threshold.
    private var ramAccent: ReadoutAccent? {
        ReadoutBuilder.rows(for: snapshot, settings: settings).first { $0.id == "ram" }?.accent
    }
}
