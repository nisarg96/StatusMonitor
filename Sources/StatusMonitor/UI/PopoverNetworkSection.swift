import StatusMonitorCore
import SwiftUI

/**
 Network: download and upload rates, a 210 x 34 sparkline (upload solid, download dashed) that shows a tooltip on
 hover, and today's totals.
 */
struct PopoverNetworkSection: View {
    /// The latest upload rate, in bytes per second.
    let upBps: Double
    /// The latest download rate, in bytes per second.
    let downBps: Double
    /// The upload history charted as a solid line.
    let upHistory: TimedSampleHistory
    /// The download history charted as a dashed line.
    let downHistory: TimedSampleHistory
    /// Today's totals, or nil when there are none.
    let today: DailyTraffic?
    /// The directions the user has switched on. Only these get a row and a chart line.
    let directions: [NetworkDirection]
    /// The section's checkbox state.
    let shown: Bool
    /// Called with the new visibility when the section's checkbox changes.
    let onToggle: (Bool) -> Void

    var body: some View {
        PopoverSectionCard(title: "Network", shown: shown, onToggle: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                if directions.contains(.download) {
                    arrowRow("↓ Download", Format.rate(downBps), PopoverPalette.downloadArrow)
                }
                if directions.contains(.upload) {
                    arrowRow("↑ Upload", Format.rate(upBps), PopoverPalette.accent)
                }
                if !lines.isEmpty, !upHistory.samples.isEmpty {
                    ChartHoverChart(
                        lines: lines,
                        yDomain: nil,
                        tooltip: { index in
                            guard let upValue = upHistory.value(at: index),
                                  let downValue = downHistory.value(at: index) else { return [] }
                            return ChartTooltipText.network(upBps: upValue, downBps: downValue, directions: directions)
                        }
                    )
                    .frame(width: 210)
                }
                if let today, let line = todayLine(today) {
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(PopoverPalette.secondaryText)
                }
            }
        }
    }

    /// The chart lines for the shown directions: upload solid, download dashed.
    private var lines: [ChartLine] {
        var result: [ChartLine] = []
        if directions.contains(.upload) {
            result.append(ChartLine(id: "upload", history: upHistory, color: PopoverPalette.fill))
        }
        if directions.contains(.download) {
            result.append(ChartLine(id: "download", history: downHistory, color: PopoverPalette.download, dashed: true))
        }
        return result
    }

    /// Today's totals for the shown directions, or nil when none is shown.
    private func todayLine(_ today: DailyTraffic) -> String? {
        var parts: [String] = []
        if directions.contains(.upload) { parts.append("↑ \(ByteCountFormat.text(today.upBytes))") }
        if directions.contains(.download) { parts.append("↓ \(ByteCountFormat.text(today.downBytes))") }
        return parts.isEmpty ? nil : "Today " + parts.joined(separator: " · ")
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
