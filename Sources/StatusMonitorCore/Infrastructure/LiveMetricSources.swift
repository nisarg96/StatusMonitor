import Foundation

/**
 Builds the production `MetricSources` from the live adapters.

 The GUI composition root and the headless dump command both call this, so they share one wiring.
 */
public enum LiveMetricSources {
    /**
     Creates a `MetricSources` value with every collector wired to its live adapter.

     - Returns: Fresh adapter instances for every collector, each reading from its live source.
     */
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
