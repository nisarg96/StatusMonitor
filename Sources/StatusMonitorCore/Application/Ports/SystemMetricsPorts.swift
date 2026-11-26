import Foundation

// Ports: the application layer's view of the outside world. Adapters live in Infrastructure.
// Every optional-collector port returns nil when the data is unavailable. Nil is never converted to 0.

/// Source of cumulative CPU tick counters.
public protocol CPUTickSource {
    /// Returns nil if the counters cannot be read.
    func readTicks() -> CPUTicks?
}

/// Source of used-RAM figures.
public protocol MemoryUsageSource {
    /// Returns nil if memory statistics cannot be read.
    func readUsedBytes() -> UInt64?
}

/// Source of per-interface link-layer counters.
public protocol InterfaceCounterSource {
    func readInterfaces() -> [InterfaceCounters]
}

/// GPU utilization and VRAM (IOAccelerator).
public protocol GPUSource {
    func read() -> GPUReading?
}

/// Kernel memory pressure level.
public protocol MemoryPressureSource {
    func readLevel() -> MemoryPressureLevel?
}

/// Cumulative disk byte counters (IOBlockStorageDriver).
public protocol DiskCounterSource {
    func readCounters() -> DiskCounters?
}

/// Internal battery state.
public protocol BatterySource {
    func read() -> BatteryReading?
}

/// Thermal and fan readings. Reads run off the main thread, so `read` returns the most recent
/// completed reading and `requestRefresh` schedules the next one.
public protocol ThermalSource: AnyObject {
    /// Opens the sensor connection and checks whether any reading works. Call once, off the main thread.
    func probe() -> Bool
    /// Most recent completed reading. Nil when none is available.
    func latest() -> ThermalReading?
    /// Starts a background read if none is in flight. Never blocks.
    func requestRefresh()
}

/// Persistence port for user settings.
public protocol SettingsRepository: AnyObject {
    func load() -> MetricSettings
    func save(_ settings: MetricSettings)
}

/// Monotonic time source, injectable so rate maths can be tested deterministically.
public protocol MonotonicClock {
    func nanoseconds() -> UInt64
}

/// Drives periodic refreshes. Implemented with a RunLoop timer in Infrastructure.
/// Calling `schedule` replaces any previous cadence, so there is only ever one timer.
public protocol RefreshScheduling: AnyObject {
    func schedule(every interval: TimeInterval, action: @escaping () -> Void)
    func cancel()
}
