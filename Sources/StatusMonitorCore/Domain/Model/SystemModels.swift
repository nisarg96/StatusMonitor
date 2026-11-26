import Foundation

/// Cumulative CPU tick counters since boot (host_cpu_load_info). 32-bit, wrap on overflow.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// One AF_LINK record, reduced to what the domain needs.
/// rxBytes/txBytes come from if_data.ifi_ibytes/ifi_obytes (32-bit, wrap on overflow).
public struct InterfaceCounters: Equatable, Sendable {
    public let name: String
    public let isUp: Bool
    public let isRunning: Bool
    public let isLoopback: Bool
    public let rxBytes: UInt32
    public let txBytes: UInt32

    public init(name: String, isUp: Bool, isRunning: Bool, isLoopback: Bool, rxBytes: UInt32, txBytes: UInt32) {
        self.name = name
        self.isUp = isUp
        self.isRunning = isRunning
        self.isLoopback = isLoopback
        self.rxBytes = rxBytes
        self.txBytes = txBytes
    }
}

/// Everything the app can display, sampled at one instant.
/// A nil optional field means "not shown". It never means zero.
public struct SystemSnapshot: Equatable, Sendable {
    /// Busy CPU percentage, 0...100.
    public var cpuPercent: Double
    /// Used RAM in bytes (app + wired + compressed).
    public var memoryUsedBytes: UInt64
    /// Bytes per second received / sent on the included interfaces.
    public var downBps: Double
    public var upBps: Double
    /// Bytes received / sent since the previous sample. Traffic totals add these directly, so a long gap
    /// (sleep, or a paused collector) is counted by the bytes that moved, not by rate times the nominal interval.
    public var downBytesSinceLastSample: Double
    public var upBytesSinceLastSample: Double

    public var gpu: GPUReading?
    public var memoryPressure: MemoryPressureLevel?
    public var disk: DiskRates?
    public var battery: BatteryReading?
    public var thermal: ThermalReading?
    /// False until a reading has its CPU and rate baselines, so the values above are not yet real. Unsampled items
    /// show their icon alone, and the popover shows "--". Snapshots built by hand count as sampled.
    public var isSampled: Bool

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

    /// Clears every optional collector that is not in `enabled`, so a just-disabled
    /// collector disappears immediately instead of lingering until the next sample.
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
