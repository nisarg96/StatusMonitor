import Foundation

/// Builds the production `MetricSources` from the live adapters.
/// Shared by the GUI composition root and the headless dump command, so both use the same wiring.
public enum LiveMetricSources {
    public static func make() -> MetricSources {
        MetricSources(
            cpuTicks: MachCPUTickSource(),
            memory: MachMemoryUsageSource(),
            interfaces: GetIfAddrsInterfaceSource(),
            clock: SystemMonotonicClock(),
            gpu: IOKitGPUSource(),
            memoryPressure: SysctlMemoryPressureSource(),
            disk: IOKitDiskCounterSource(),
            battery: IOKitBatterySource(),
            thermal: SMCThermalSource()
        )
    }
}
