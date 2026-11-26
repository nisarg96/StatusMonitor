import Charts
import StatusMonitorCore
import SwiftUI

/// One line on a chart. Used by the Settings history preview; the popover uses `ChartLine` for its hover charts.
struct ChartSeries: Identifiable {
    /// The series' identifier, which names it in the chart's data.
    let id: String
    /// The samples, oldest first.
    let values: [Double]
    /// The line's colour.
    let color: Color
    /// Draws the line dashed when true.
    var dashed = false
}

/// Summary figures for a history, shown as small text under the chart. Hidden when there is no history.
struct HistoryStats: View {
    /// The minimum, average and maximum of the history, or nil when there is no history.
    let stats: SeriesStatistics?
    /// Formats one figure for display, such as a percent or a rate.
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
    /// The lines to draw, all sharing one y scale.
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
