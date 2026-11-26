import Foundation

/**
 The optional collectors.

 CPU, RAM, and network are always available and are not listed here. Each one is probed once at launch. If its probe
 fails, it is hidden everywhere and never shown as 0 or N/A.
 */
public enum CollectorKind: String, CaseIterable, Hashable, Sendable {
    /// GPU utilization and VRAM.
    case gpu
    /// The kernel memory pressure level.
    case memoryPressure
    /// Disk throughput.
    case disk
    /// The internal battery.
    case battery
    /// Thermal sensors and fans.
    case thermal
}

/// Which collectors the current Mac can provide. Filled in by the capability probe at launch.
public struct MetricCapabilities: Equatable, Sendable {
    /// The collectors the Mac can provide.
    public var available: Set<CollectorKind>

    /**
     Creates the capabilities.

     - Parameter available: The collectors the Mac can provide. Empty by default.
     */
    public init(available: Set<CollectorKind> = []) {
        self.available = available
    }

    /**
     Reports whether the Mac can provide a collector.

     - Parameter kind: The collector to check.
     - Returns: True when the collector is in `available`.
     */
    public func supports(_ kind: CollectorKind) -> Bool {
        available.contains(kind)
    }
}

/**
 Kernel-reported memory pressure, from `kern.memorystatus_vm_pressure_level`.

 The raw values are 1, 2, and 4. Other values are rejected rather than guessed.
 */
public enum MemoryPressureLevel: String, Equatable, Sendable {
    /// The kernel reports normal memory pressure.
    case normal
    /// The kernel reports warning memory pressure.
    case warning
    /// The kernel reports critical memory pressure.
    case critical

    /**
     Creates a level from a `kern.memorystatus_vm_pressure_level` value.

     - Parameter sysctlValue: The raw kernel value: 1 for normal, 2 for warning, or 4 for critical.
     - Returns: The matching level, or nil for any other value.
     */
    public init?(sysctlValue: Int32) {
        switch sysctlValue {
        case 1: self = .normal
        case 2: self = .warning
        case 4: self = .critical
        default: return nil
        }
    }

    /// A display name for the level, such as "Warning".
    public var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

/// GPU load from the accelerator's PerformanceStatistics. VRAM is optional: some GPUs do not report it.
public struct GPUReading: Equatable, Sendable {
    /// GPU utilization in percent, 0...100.
    public var utilizationPercent: Double
    /// VRAM in use, in bytes. Nil when the GPU does not report it.
    public var vramUsedBytes: UInt64?
    /// Total VRAM in bytes, which is used plus free. Nil when the GPU does not report it.
    public var vramTotalBytes: UInt64?

    /**
     Creates a GPU reading.

     - Parameters:
       - utilizationPercent: GPU utilization in percent, 0...100.
       - vramUsedBytes: VRAM in use, in bytes, or nil when not reported.
       - vramTotalBytes: Total VRAM in bytes, or nil when not reported.
     */
    public init(utilizationPercent: Double, vramUsedBytes: UInt64? = nil, vramTotalBytes: UInt64? = nil) {
        self.utilizationPercent = utilizationPercent
        self.vramUsedBytes = vramUsedBytes
        self.vramTotalBytes = vramTotalBytes
    }
}

/// Cumulative bytes read and written across all block storage drivers since boot.
public struct DiskCounters: Equatable, Sendable {
    /// Bytes read since boot.
    public var readBytes: UInt64
    /// Bytes written since boot.
    public var writeBytes: UInt64

    /**
     Creates disk counters.

     - Parameters:
       - readBytes: Bytes read since boot.
       - writeBytes: Bytes written since boot.
     */
    public init(readBytes: UInt64, writeBytes: UInt64) {
        self.readBytes = readBytes
        self.writeBytes = writeBytes
    }
}

/// Disk throughput in bytes per second.
public struct DiskRates: Equatable, Sendable {
    /// Bytes per second read.
    public var readBps: Double
    /// Bytes per second written.
    public var writeBps: Double

    /**
     Creates disk rates.

     - Parameters:
       - readBps: Bytes per second read.
       - writeBps: Bytes per second written.
     */
    public init(readBps: Double, writeBps: Double) {
        self.readBps = readBps
        self.writeBps = writeBps
    }
}

/// Battery state from the internal battery only. Desktops have no battery, so the reader returns nil.
public struct BatteryReading: Equatable, Sendable {
    /// Charge as a whole percentage, or nil when unavailable.
    public var currentPercent: Int?
    /**
     Raw capacity over design capacity, in percent.

     Nil when either value is unavailable.
     */
    public var healthPercent: Double?
    /// The battery's charge cycle count, or nil when unavailable.
    public var cycleCount: Int?
    /// True while the battery is charging.
    public var isCharging: Bool
    /// True while the Mac is connected to AC power.
    public var isOnACPower: Bool
    /// Time to empty when discharging, time to full when charging. Nil while the system is still estimating.
    public var minutesRemaining: Int?
    /// System Low Power Mode. This is a system setting, not a battery measurement, so the adapter fills it in.
    public var isLowPowerMode: Bool = false
    /**
     Battery power flow in watts: positive while charging, negative while discharging.

     Nil when voltage or current is unknown.
     */
    public var powerWatts: Double?

    /**
     Creates a battery reading.

     `isLowPowerMode` and `powerWatts` are not set here. They keep their defaults, `false` and nil.

     - Parameters:
       - currentPercent: Charge as a whole percentage, or nil when unavailable.
       - healthPercent: Raw capacity over design capacity in percent, or nil when unavailable.
       - cycleCount: The charge cycle count, or nil when unavailable.
       - isCharging: True while the battery is charging.
       - isOnACPower: True while the Mac is connected to AC power.
       - minutesRemaining: Minutes to empty or to full, or nil while estimating.
     */
    public init(
        currentPercent: Int?,
        healthPercent: Double?,
        cycleCount: Int?,
        isCharging: Bool,
        isOnACPower: Bool,
        minutesRemaining: Int?
    ) {
        self.currentPercent = currentPercent
        self.healthPercent = healthPercent
        self.cycleCount = cycleCount
        self.isCharging = isCharging
        self.isOnACPower = isOnACPower
        self.minutesRemaining = minutesRemaining
    }
}

/// The speed of one fan.
public struct FanSpeed: Equatable, Sendable {
    /// Zero-based fan index, matching the SMC key F<index>Ac.
    public var index: Int
    /// Fan speed in revolutions per minute.
    public var rpm: Int

    /**
     Creates a fan speed.

     - Parameters:
       - index: Zero-based fan index.
       - rpm: Fan speed in revolutions per minute.
     */
    public init(index: Int, rpm: Int) {
        self.index = index
        self.rpm = rpm
    }
}

/// Thermal sensors and fans from the SMC. Fanless Macs report an empty fan list.
public struct ThermalReading: Equatable, Sendable {
    /// CPU temperature in degrees Celsius, or nil when unavailable.
    public var cpuTemperatureC: Double?
    /// The fans the SMC reports. Empty on a fanless Mac.
    public var fans: [FanSpeed]

    /**
     Creates a thermal reading.

     - Parameters:
       - cpuTemperatureC: CPU temperature in degrees Celsius, or nil when unavailable.
       - fans: The fans the SMC reports. Empty by default.
     */
    public init(cpuTemperatureC: Double? = nil, fans: [FanSpeed] = []) {
        self.cpuTemperatureC = cpuTemperatureC
        self.fans = fans
    }
}
