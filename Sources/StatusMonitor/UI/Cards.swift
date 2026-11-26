import Charts
import StatusMonitorCore
import SwiftUI

/// One line on a card's chart.
struct ChartSeries: Identifiable {
    let id: String
    let values: [Double]
    let color: Color
    var dashed = false
}

/// Colour for a readout state. Normal uses the default text colour; only warning and critical are coloured.
func stateColor(_ accent: ReadoutAccent?) -> Color {
    switch accent {
    case .normal, nil: return .primary
    case .warning: return Brand.warm
    case .critical: return .red
    }
}

/// Summary figures for a history, shown as small text under the chart. Hidden when there is no history.
struct HistoryStats: View {
    let stats: SeriesStatistics?
    let format: (Double) -> String

    var body: some View {
        if let stats {
            HStack(spacing: 12) {
                stat("Min", format(stats.minimum))
                stat("Avg", format(stats.average))
                stat("Max", format(stats.maximum))
                Spacer(minLength: 0)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
            Text(value).monospacedDigit().foregroundStyle(.primary)
        }
    }
}

/// Line chart of recent samples. Axes are hidden, so the chart stays compact in a card.
struct HistoryChart: View {
    let series: [ChartSeries]
    /// Fixed scale for percentages. Nil lets the chart fit its data.
    let yDomain: ClosedRange<Double>?

    var body: some View {
        let peak = series.flatMap(\.values).max() ?? 1
        let domain = yDomain ?? 0...max(1, peak)
        Chart {
            ForEach(series) { line in
                ForEach(Array(line.values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value(line.id, value),
                        series: .value("Series", line.id)
                    )
                    .foregroundStyle(line.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: line.dashed ? [4, 3] : []))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }
}

/// A card for one status bar item: its live value, its history, its summary figures, and a gear that opens Settings.
struct MetricCard: View {
    let title: String
    let symbol: String
    let value: String
    let accent: ReadoutAccent?
    let series: [ChartSeries]
    let yDomain: ClosedRange<Double>?
    let stats: SeriesStatistics?
    let statFormat: (Double) -> String
    /// Extra detail lines, such as battery health or the memory breakdown.
    let details: [ReadoutRow]
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(Brand.accent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 15, weight: accent == .warning || accent == .critical ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(stateColor(accent))
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure \(title) in Settings")
                .accessibilityLabel("Configure \(title)")
            }

            if !series.isEmpty {
                HistoryChart(series: series, yDomain: yDomain)
                HistoryStats(stats: stats, format: statFormat)
            }

            ForEach(details) { row in
                HStack {
                    Text(row.label).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value).monospacedDigit()
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
    }
}

/// The network card: current download and upload on the left, one combined chart on the right
/// (download solid, upload dashed), and today's totals on a line underneath.
struct NetworkCard: View {
    let down: String
    let up: String
    let downSeries: [Double]
    let upSeries: [Double]
    let downStats: SeriesStatistics?
    let today: DailyTraffic?
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundStyle(Brand.accent)
                    .frame(width: 18)
                Text("Network")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Button(action: openSettings) {
                    Image(systemName: "gearshape").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure Network in Settings")
                .accessibilityLabel("Configure Network")
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    labelled("Download", down, Brand.accent)
                    labelled("Upload", up, Brand.warm)
                }
                .frame(width: 112, alignment: .leading)

                HistoryChart(
                    series: [
                        ChartSeries(id: "download", values: downSeries, color: Brand.accent),
                        ChartSeries(id: "upload", values: upSeries, color: Brand.warm, dashed: true),
                    ],
                    yDomain: nil
                )
            }

            HistoryStats(stats: downStats) { Format.rate($0) }

            if let today {
                HStack {
                    Text("Today").foregroundStyle(.secondary)
                    Spacer()
                    Text("↑ \(Format.gib(UInt64(today.upBytes)))  ↓ \(Format.gib(UInt64(today.downBytes)))")
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
    }

    private func labelled(_ label: String, _ value: String, _ colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(colour)
        }
    }
}
