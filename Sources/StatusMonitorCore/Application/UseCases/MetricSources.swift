import Foundation

/**
 Every port the sampling use case needs, bundled for injection.

 The composition root builds this once from the live adapters, and tests build it from fakes.
 */
public struct MetricSources {
    /// Source of cumulative CPU tick counters.
    public let cpuTicks: CPUTickSource
    /// Source of used-RAM figures.
    public let memory: MemoryUsageSource
    /// Source of per-interface link-layer counters.
    public let interfaces: InterfaceCounterSource
    /// Monotonic clock used to measure the real time between samples.
    public let clock: MonotonicClock
    /// Source of GPU utilization and VRAM.
    public let gpu: GPUSource
    /// Source of the kernel memory pressure level.
    public let memoryPressure: MemoryPressureSource
    /// Source of cumulative disk byte counters.
    public let disk: DiskCounterSource
    /// Source of the internal battery state.
    public let battery: BatterySource
    /// Source of thermal and fan readings.
    public let thermal: ThermalSource

    /**
     Creates the bundle.

     - Parameters:
       - cpuTicks: Source of cumulative CPU tick counters.
       - memory: Source of used-RAM figures.
       - interfaces: Source of per-interface link-layer counters.
       - clock: Monotonic clock used to measure elapsed time.
       - gpu: Source of GPU utilization and VRAM.
       - memoryPressure: Source of the kernel memory pressure level.
       - disk: Source of cumulative disk byte counters.
       - battery: Source of the internal battery state.
       - thermal: Source of thermal and fan readings.
     */
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
