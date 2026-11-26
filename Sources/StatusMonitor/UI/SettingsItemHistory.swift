import StatusMonitorCore
import SwiftUI

/// The item's recent history, drawn the same way as on its card. Shown only once there are samples.
struct SettingsItemHistory: View {
    /// The menu bar item whose history is shown.
    let item: MetricItemID
    /// The monitor that supplies the histories.
    @ObservedObject var monitor: MonitorViewModel

    var body: some View {
        let series = Self.series(for: item, histories: monitor.histories)
        if series.contains(where: { !$0.values.isEmpty }) {
            let domain: ClosedRange<Double>? = (item == .cpu || item == .gpu) ? 0...100 : nil
            SettingsGroup(title: "History") {
                HistoryChart(series: series, yDomain: domain)
                HistoryStats(stats: SeriesStatistics.of(series.first?.values ?? []),
                             format: { Self.format(item, $0) })
            }
        }
    }

    /**
     Formats a value of an item's history for display.

     - Parameter item: The menu bar item the value belongs to.
     - Parameter value: The value to format.
     - Returns: A rate for network and disk, a temperature for thermal, and a percent otherwise.
     */
    static func format(_ item: MetricItemID, _ value: Double) -> String {
        switch item {
        case .network, .disk: return Format.rate(value)
        case .thermal: return Format.celsius(value)
        default: return Format.percent(value)
        }
    }

    /**
     Returns the chart series for an item, with their colours and dash styles.

     - Parameter item: The menu bar item.
     - Parameter histories: The histories keyed by series.
     - Returns: The series to chart. Items with no history return an empty list.
     */
    static func series(for item: MetricItemID, histories: [HistorySeries: SampleHistory]) -> [ChartSeries] {
        func values(_ key: HistorySeries) -> [Double] { histories[key]?.values ?? [] }
        switch item {
        case .cpu: return [ChartSeries(id: "cpu", values: values(.cpu), color: Brand.accent)]
        case .gpu: return [ChartSeries(id: "gpu", values: values(.gpu), color: Brand.accent)]
        case .network:
            return [
                ChartSeries(id: "download", values: values(.networkDown), color: Brand.accent),
                ChartSeries(id: "upload", values: values(.networkUp), color: Brand.warm, dashed: true)
            ]
        case .disk:
            return [
                ChartSeries(id: "read", values: values(.diskRead), color: Brand.accent),
                ChartSeries(id: "write", values: values(.diskWrite), color: Brand.warm, dashed: true)
            ]
        case .thermal:
            return [ChartSeries(id: "temperature", values: values(.temperature), color: Brand.accent)]
        case .ram, .memoryPressure, .battery: return []
        }
    }
}
