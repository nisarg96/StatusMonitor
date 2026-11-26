import Foundation

/// The optional collectors. CPU, RAM, and network are always available and are not listed here.
/// Each one is probed once at launch. If its probe fails, it is hidden everywhere and never shown as 0 or N/A.
public enum CollectorKind: String, CaseIterable, Hashable, Sendable {
    case gpu
    case memoryPressure
    case disk
    case battery
    case thermal
}

/// Which collectors the current Mac can provide. Filled in by the capability probe at launch.
public struct MetricCapabilities: Equatable, Sendable {
    public var available: Set<CollectorKind>

    public init(available: Set<CollectorKind> = []) {
        self.available = available
    }

    public func supports(_ kind: CollectorKind) -> Bool {
        available.contains(kind)
    }
}

/// Kernel-reported memory pressure (kern.memorystatus_vm_pressure_level).
/// The raw values are 1, 2, and 4. Other values are rejected rather than guessed.
public enum MemoryPressureLevel: String, Equatable, Sendable {
    case normal
    case warning
    case critical

    public init?(sysctlValue: Int32) {
        switch sysctlValue {
        case 1: self = .normal
        case 2: self = .warning
        case 4: self = .critical
        default: return nil
        }
    }

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
    public var utilizationPercent: Double
    public var vramUsedBytes: UInt64?
    public var vramTotalBytes: UInt64?

    public init(utilizationPercent: Double, vramUsedBytes: UInt64? = nil, vramTotalBytes: UInt64? = nil) {
        self.utilizationPercent = utilizationPercent
        self.vramUsedBytes = vramUsedBytes
        self.vramTotalBytes = vramTotalBytes
    }
}

/// Cumulative bytes read and written across all block storage drivers since boot.
public struct DiskCounters: Equatable, Sendable {
    public var readBytes: UInt64
    public var writeBytes: UInt64

    public init(readBytes: UInt64, writeBytes: UInt64) {
        self.readBytes = readBytes
        self.writeBytes = writeBytes
    }
}

/// Disk throughput in bytes per second.
public struct DiskRates: Equatable, Sendable {
    public var readBps: Double
    public var writeBps: Double

    public init(readBps: Double, writeBps: Double) {
        self.readBps = readBps
        self.writeBps = writeBps
    }
}

/// Battery state from the internal battery only. Desktops have no battery, so the reader returns nil.
public struct BatteryReading: Equatable, Sendable {
    public var currentPercent: Int?
    /// Raw capacity over design capacity, in percent. Nil when either value is unavailable.
    public var healthPercent: Double?
    public var cycleCount: Int?
    public var isCharging: Bool
    public var isOnACPower: Bool
    /// Time to empty when discharging, time to full when charging. Nil while the system is still estimating.
    public var minutesRemaining: Int?
    /// System Low Power Mode. This is a system setting, not a battery measurement, so the adapter fills it in.
    public var isLowPowerMode: Bool = false
    /// Battery power flow in watts: positive while charging, negative while discharging. Nil when voltage or current
    /// is unknown.
    public var powerWatts: Double?

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

public struct FanSpeed: Equatable, Sendable {
    /// Zero-based fan index, matching the SMC key F<index>Ac.
    public var index: Int
    public var rpm: Int

    public init(index: Int, rpm: Int) {
        self.index = index
        self.rpm = rpm
    }
}

/// Thermal sensors and fans from the SMC. Fanless Macs report an empty fan list.
public struct ThermalReading: Equatable, Sendable {
    public var cpuTemperatureC: Double?
    public var fans: [FanSpeed]

    public init(cpuTemperatureC: Double? = nil, fans: [FanSpeed] = []) {
        self.cpuTemperatureC = cpuTemperatureC
        self.fans = fans
    }
}
