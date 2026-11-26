import Foundation
import StatusMonitorCore

/**
 The headless diagnostic behind `StatusMonitor --dump-samples [count]`.

 It runs the same probe, use case and formatter as the GUI and prints the menu bar text every 2 s. It also prints the
 probe result and the raw readings, so they can be compared with system tools.
 */
enum SampleDumpCommand {
    /**
     Prints the probe result, then a baseline reading, then one menu bar line and its readout rows per sample.

     The loop uses `stride`, which never traps. A count below 1 therefore prints no samples, where a closed range
     `1...count` would trap.

     - Parameter count: The number of samples to print after the baseline.
     - Parameter sources: The metric sources to read from.
     - Parameter settings: The settings that decide the menu bar text and the readout rows.
     */
    static func run(count: Int, sources: MetricSources, settings: MetricSettings) {
        setbuf(stdout, nil)

        let capabilities = CapabilityProbe(sources: sources).run()
        let enabled = settings.enabledCollectors(capabilities: capabilities)
        print("capabilities: \(capabilities.available.map(\.rawValue).sorted().joined(separator: ", "))")

        let useCase = SampleSystemMetricsUseCase(sources: sources)
        useCase.updateConfiguration(filter: InterfaceFilter.from(settings), enabled: enabled)
        _ = useCase.execute()

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
