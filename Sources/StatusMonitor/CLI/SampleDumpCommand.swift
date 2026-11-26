import Foundation
import StatusMonitorCore

/// Headless diagnostic: `StatusMonitor --dump-samples [count]`.
/// Runs the same probe, use case, and formatter as the GUI, and prints the menu bar text every 2 s.
/// It also prints the probe result and the raw readings, so you can compare them with system tools.
enum SampleDumpCommand {
    static func run(count: Int, sources: MetricSources, settings: MetricSettings) {
        setbuf(stdout, nil)

        let capabilities = CapabilityProbe(sources: sources).run()
        let enabled = settings.enabledCollectors(capabilities: capabilities)
        print("capabilities: \(capabilities.available.map(\.rawValue).sorted().joined(separator: ", "))")

        let useCase = SampleSystemMetricsUseCase(sources: sources)
        useCase.updateConfiguration(filter: InterfaceFilter.from(settings), enabled: enabled)
        _ = useCase.execute() // baseline

        // stride never traps, even for a count below 1 (a closed range 1...count would).
        for index in stride(from: 1, through: count, by: 1) {
            Thread.sleep(forTimeInterval: MonitorViewModel.openInterval)
            let snapshot = useCase.execute()
            print("[\(index)] \(StatusTitleFormatter.title(for: snapshot, settings: settings))")
            for row in ReadoutBuilder.rows(for: snapshot, settings: settings) {
                print("      \(row.label): \(row.value)")
            }
        }
    }
}
