import Foundation

/**
 Cumulative CPU tick counters since boot, from `host_cpu_load_info`.

 The counters are 32-bit and wrap on overflow.
 */
public struct CPUTicks: Equatable, Sendable {
    /// Ticks spent in user mode.
    public var user: UInt32
    /// Ticks spent in kernel mode.
    public var system: UInt32
    /// Ticks spent idle.
    public var idle: UInt32
    /// Ticks spent in user mode at nice priority.
    public var nice: UInt32

    /**
     Creates tick counters.

     - Parameters:
       - user: Ticks spent in user mode.
       - system: Ticks spent in kernel mode.
       - idle: Ticks spent idle.
       - nice: Ticks spent in user mode at nice priority.
     */
    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/**
 One AF_LINK record, reduced to what the domain needs.

 `rxBytes` and `txBytes` come from `if_data.ifi_ibytes` and `if_data.ifi_obytes`. They are 32-bit and wrap on overflow.
 */
public struct InterfaceCounters: Equatable, Sendable {
    /// The interface name, such as `en0`.
    public let name: String
    /// True when the interface is up.
    public let isUp: Bool
    /// True when the interface is running.
    public let isRunning: Bool
    /// True for the loopback interface.
    public let isLoopback: Bool
    /// Cumulative bytes received, as a 32-bit counter.
    public let rxBytes: UInt32
    /// Cumulative bytes sent, as a 32-bit counter.
    public let txBytes: UInt32

    /**
     Creates an interface record.

     - Parameters:
       - name: The interface name, such as `en0`.
       - isUp: True when the interface is up.
       - isRunning: True when the interface is running.
       - isLoopback: True for the loopback interface.
       - rxBytes: Cumulative bytes received, as a 32-bit counter.
       - txBytes: Cumulative bytes sent, as a 32-bit counter.
     */
    public init(name: String, isUp: Bool, isRunning: Bool, isLoopback: Bool, rxBytes: UInt32, txBytes: UInt32) {
        self.name = name
        self.isUp = isUp
        self.isRunning = isRunning
        self.isLoopback = isLoopback
        self.rxBytes = rxBytes
        self.txBytes = txBytes
    }
}

/**
 Everything the app can display, sampled at one instant.

 A nil optional field means "not shown". It never means zero.
 */
public struct SystemSnapshot: Equatable, Sendable {
    /// Busy CPU percentage, 0...100.
    public var cpuPercent: Double
    /// Used RAM in bytes (app + wired + compressed).
    public var memoryUsedBytes: UInt64
    /// Bytes per second received on the included interfaces.
    public var downBps: Double
    /// Bytes per second sent on the included interfaces.
    public var upBps: Double
    /**
     Bytes received since the previous sample.

     Traffic totals add these directly, so a long gap (sleep, or a paused collector) is counted by the bytes that moved,
     not by rate times the nominal interval.
     */
    public var downBytesSinceLastSample: Double
    /// Bytes sent since the previous sample. See `downBytesSinceLastSample`.
    public var upBytesSinceLastSample: Double

    /// The GPU reading, or nil when not shown.
    public var gpu: GPUReading?
    /// The memory pressure level, or nil when not shown.
    public var memoryPressure: MemoryPressureLevel?
    /// The disk throughput, or nil when not shown.
    public var disk: DiskRates?
    /// The battery reading, or nil when not shown.
    public var battery: BatteryReading?
    /// The thermal reading, or nil when not shown.
    public var thermal: ThermalReading?
    /**
     False until a reading has its CPU and rate baselines, so the values above are not yet real.

     Unsampled items show their icon alone, and the popover shows "--". Snapshots built by hand count as sampled.
     */
    public var isSampled: Bool

    /**
     Creates a snapshot. Every parameter has a default.

     - Parameters:
       - cpuPercent: Busy CPU percentage, 0...100. Defaults to 0.
       - memoryUsedBytes: Used RAM in bytes. Defaults to 0.
       - downBps: Bytes per second received. Defaults to 0.
       - upBps: Bytes per second sent. Defaults to 0.
       - downBytesSinceLastSample: Bytes received since the previous sample. Defaults to 0.
       - upBytesSinceLastSample: Bytes sent since the previous sample. Defaults to 0.
       - gpu: The GPU reading, or nil when not shown.
       - memoryPressure: The memory pressure level, or nil when not shown.
       - disk: The disk throughput, or nil when not shown.
       - battery: The battery reading, or nil when not shown.
       - thermal: The thermal reading, or nil when not shown.
       - isSampled: Whether the values are real readings. Defaults to true, because hand-built snapshots count as
         sampled.
     */
    public init(
        cpuPercent: Double = 0,
        memoryUsedBytes: UInt64 = 0,
        downBps: Double = 0,
        upBps: Double = 0,
        downBytesSinceLastSample: Double = 0,
        upBytesSinceLastSample: Double = 0,
        gpu: GPUReading? = nil,
        memoryPressure: MemoryPressureLevel? = nil,
        disk: DiskRates? = nil,
        battery: BatteryReading? = nil,
        thermal: ThermalReading? = nil,
        isSampled: Bool = true
    ) {
        self.isSampled = isSampled
        self.cpuPercent = cpuPercent
        self.memoryUsedBytes = memoryUsedBytes
        self.downBps = downBps
        self.upBps = upBps
        self.downBytesSinceLastSample = downBytesSinceLastSample
        self.upBytesSinceLastSample = upBytesSinceLastSample
        self.gpu = gpu
        self.memoryPressure = memoryPressure
        self.disk = disk
        self.battery = battery
        self.thermal = thermal
    }

    /**
     Returns a copy with every optional collector that is not enabled cleared.

     A just-disabled collector disappears immediately instead of lingering until the next sample.

     - Parameter enabled: The optional collectors that are still enabled.
     - Returns: The copy, with each collector outside `enabled` set to nil.
     */
    public func retaining(_ enabled: Set<CollectorKind>) -> SystemSnapshot {
        var copy = self
        if !enabled.contains(.gpu) { copy.gpu = nil }
        if !enabled.contains(.memoryPressure) { copy.memoryPressure = nil }
        if !enabled.contains(.disk) { copy.disk = nil }
        if !enabled.contains(.battery) { copy.battery = nil }
        if !enabled.contains(.thermal) { copy.thermal = nil }
        return copy
    }
}
