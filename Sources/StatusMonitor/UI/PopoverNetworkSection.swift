import StatusMonitorCore
import SwiftUI

/// Network: download and upload rates, a 210 x 34 sparkline (upload solid, download dashed) that shows a tooltip on
/// hover, and today's totals.
struct PopoverNetworkSection: View {
    let upBps: Double
    let downBps: Double
    let upHistory: TimedSampleHistory
    let downHistory: TimedSampleHistory
    let today: DailyTraffic?
    let shown: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        PopoverSectionCard(title: "Network", shown: shown, onToggle: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                arrowRow("↓ Download", Format.rate(downBps), PopoverPalette.downloadArrow)
                arrowRow("↑ Upload", Format.rate(upBps), PopoverPalette.accent)
                if !upHistory.samples.isEmpty {
                    ChartHoverChart(
                        lines: [
                            ChartLine(id: "upload", history: upHistory, color: PopoverPalette.fill),
                            ChartLine(
                                id: "download", history: downHistory, color: PopoverPalette.download, dashed: true
                            )
                        ],
                        yDomain: nil,
                        tooltip: { index in
                            guard let upValue = upHistory.value(at: index),
                                  let downValue = downHistory.value(at: index) else { return [] }
                            return ChartTooltipText.network(upBps: upValue, downBps: downValue)
                        }
                    )
                    .frame(width: 210)
                }
                if let today {
                    Text("Today ↑ \(ByteCountFormat.text(today.upBytes)) · ↓ \(ByteCountFormat.text(today.downBytes))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(PopoverPalette.secondaryText)
                }
            }
        }
    }

    /// A label whose arrow takes its own colour, then the value in the text colour.
    private func arrowRow(_ label: String, _ value: String, _ arrowColor: Color) -> some View {
        let arrow = String(label.prefix(1))
        let name = String(label.dropFirst(2))
        return HStack(spacing: 0) {
            Text(arrow + " ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(arrowColor)
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(PopoverPalette.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(PopoverPalette.text)
        }
    }
}
