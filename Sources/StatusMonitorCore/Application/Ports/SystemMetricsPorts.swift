import Foundation

/// Source of cumulative CPU tick counters since boot.
public protocol CPUTickSource {
    /**
     Reads the cumulative CPU tick counters.

     - Returns: The counters, or nil when they cannot be read.
     */
    func readTicks() -> CPUTicks?
}

/// Source of used-RAM figures.
public protocol MemoryUsageSource {
    /**
     Reads the used RAM.

     - Returns: Used RAM in bytes (app + wired + compressed), or nil when memory statistics cannot be read.
     */
    func readUsedBytes() -> UInt64?
}

/// Source of per-interface link-layer counters.
public protocol InterfaceCounterSource {
    /**
     Reads the link-layer counters for each network interface.

     - Returns: One record per interface.
     */
    func readInterfaces() -> [InterfaceCounters]
}

/// GPU utilization and VRAM, read from IOAccelerator.
public protocol GPUSource {
    /**
     Reads the GPU utilization and, when the GPU reports them, its VRAM.

     - Returns: The reading, or nil when no usable utilization value is available. Nil is never converted to 0.
     */
    func read() -> GPUReading?
}

/// Kernel memory pressure level.
public protocol MemoryPressureSource {
    /**
     Reads the kernel memory pressure level.

     - Returns: The level, or nil when it cannot be read. Nil is never converted to a zero value.
     */
    func readLevel() -> MemoryPressureLevel?
}

/// Cumulative disk byte counters, read from IOBlockStorageDriver.
public protocol DiskCounterSource {
    /**
     Reads the cumulative disk byte counters.

     - Returns: The counters, or nil when they cannot be read. Nil is never converted to 0.
     */
    func readCounters() -> DiskCounters?
}

/// Internal battery state.
public protocol BatterySource {
    /**
     Reads the internal battery state.

     - Returns: The reading, or nil on a Mac without an internal battery or when it cannot be read. Nil is never
       converted to 0.
     */
    func read() -> BatteryReading?
}

/**
 Thermal and fan readings from the SMC.

 Reads run off the main thread. `latest()` returns the most recent completed reading without blocking, and
 `requestRefresh()` schedules the next one.
 */
public protocol ThermalSource: AnyObject {
    /**
     Opens the sensor connection and checks whether any reading works.

     Call once, off the main thread.

     - Returns: True when at least one thermal reading works.
     */
    func probe() -> Bool

    /**
     Returns the most recent completed reading.

     - Returns: The reading, or nil when none is available. Nil is never converted to 0.
     */
    func latest() -> ThermalReading?

    /**
     Starts a background read if none is in flight.

     This never blocks.
     */
    func requestRefresh()
}

/// Persistence port for user settings.
public protocol SettingsRepository: AnyObject {
    /**
     Loads the stored settings.

     - Returns: The stored settings, with defaults for any value that is not stored.
     */
    func load() -> MetricSettings

    /**
     Persists the settings.

     - Parameter settings: The settings to store.
     */
    func save(_ settings: MetricSettings)
}

/**
 Monotonic time source, injectable so rate calculations can be tested deterministically.

 The absolute value has no meaning. Only the difference between two readings is used.
 */
public protocol MonotonicClock {
    /**
     Reads the monotonic clock.

     - Returns: Nanoseconds from the monotonic clock.
     */
    func nanoseconds() -> UInt64
}

/**
 Drives periodic refreshes. The Infrastructure adapter uses a RunLoop timer.

 Calling `schedule` replaces any previous cadence, so there is only ever one timer.
 */
public protocol RefreshScheduling: AnyObject {
    /**
     Starts calling `action` at a fixed interval, replacing any earlier schedule.

     - Parameters:
       - interval: Seconds between calls.
       - action: The closure to run on each tick.
     */
    func schedule(every interval: TimeInterval, action: @escaping () -> Void)

    /// Stops the timer.
    func cancel()
}
