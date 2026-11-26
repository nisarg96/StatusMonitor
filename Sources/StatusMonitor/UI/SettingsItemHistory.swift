import StatusMonitorCore
import SwiftUI

/// The item's recent history, drawn the same way as on its card. Shown only once there are samples.
struct SettingsItemHistory: View {
    let item: MetricItemID
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

    static func format(_ item: MetricItemID, _ value: Double) -> String {
        switch item {
        case .network, .disk: return Format.rate(value)
        case .thermal: return Format.celsius(value)
        default: return Format.percent(value)
        }
    }

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
