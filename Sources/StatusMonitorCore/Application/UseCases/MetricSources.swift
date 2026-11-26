import Foundation

/// Every port the sampling use case needs, bundled for injection.
/// The composition root builds this once from the live adapters, and tests build it from fakes.
public struct MetricSources {
    public let cpuTicks: CPUTickSource
    public let memory: MemoryUsageSource
    public let interfaces: InterfaceCounterSource
    public let clock: MonotonicClock
    public let gpu: GPUSource
    public let memoryPressure: MemoryPressureSource
    public let disk: DiskCounterSource
    public let battery: BatterySource
    public let thermal: ThermalSource

    public init(
        cpuTicks: CPUTickSource,
        memory: MemoryUsageSource,
        interfaces: InterfaceCounterSource,
        clock: MonotonicClock,
        gpu: GPUSource,
        memoryPressure: MemoryPressureSource,
        disk: DiskCounterSource,
        battery: BatterySource,
        thermal: ThermalSource
    ) {
        self.cpuTicks = cpuTicks
        self.memory = memory
        self.interfaces = interfaces
        self.clock = clock
        self.gpu = gpu
        self.memoryPressure = memoryPressure
        self.disk = disk
        self.battery = battery
        self.thermal = thermal
    }
}
