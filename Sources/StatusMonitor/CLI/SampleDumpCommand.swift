import Foundation
import StatusMonitorCore

/// Headless diagnostic: `StatusMonitor --dump-samples [count]`.
/// Runs the same probe, use case, and formatter as the GUI, and prints the menu bar text every 2 s.
/// It also prints the probe result and the raw readings, so you can compare them with system tools.
enum SampleDumpCommand {
    static func run(count: Int, settings: MetricSettings) {
        setbuf(stdout, nil)

        let sources = LiveMetricSources.make()
        let capabilities = CapabilityProbe(sources: sources).run()
        let enabled = settings.enabledCollectors(capabilities: capabilities)
        print("capabilities: \(capabilities.available.map(\.rawValue).sorted().joined(separator: ", "))")

        let useCase = SampleSystemMetricsUseCase(sources: sources)
        useCase.updateConfiguration(filter: InterfaceFilter.from(settings), enabled: enabled)
        _ = useCase.execute() // baseline

        for i in 1...count {
            Thread.sleep(forTimeInterval: MonitorViewModel.openInterval)
            let snapshot = useCase.execute()
            print("[\(i)] \(StatusTitleFormatter.title(for: snapshot, settings: settings))")
            for row in ReadoutBuilder.rows(for: snapshot, settings: settings) {
                print("      \(row.label): \(row.value)")
            }
        }
    }
}
