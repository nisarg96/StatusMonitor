import Foundation

/// Pure parsers that turn raw IOKit dictionaries into domain readings.
/// They hold all the key-name knowledge, so the IOKit adapters stay thin and the logic is testable.

/// Reads an IOKit numeric value defensively. Anything that is not a non-negative finite number is nil.
enum IOValue {
    /// 2^64 as a Double. Any value at or above it does not fit in a UInt64, and converting it would trap.
    private static let uint64Limit: Double = 18_446_744_073_709_551_616

    static func double(_ value: Any?) -> Double? {
        let number: Double?
        switch value {
        case let nsNumber as NSNumber: number = nsNumber.doubleValue
        case let doubleValue as Double: number = doubleValue
        case let intValue as Int: number = Double(intValue)
        default: number = nil
        }
        guard let number, number.isFinite else { return nil }
        return number
    }

    static func unsigned(_ value: Any?) -> UInt64? {
        guard let number = double(value), number >= 0, number < uint64Limit else { return nil }
        return UInt64(number)
    }
}

// MARK: - GPU

enum GPUStatisticsParser {
    /// Reads "PerformanceStatistics" from an IOAccelerator. Returns nil if there is no usable utilization value.
    /// VRAM is reported only when both used and free are present, because total = used + free.
    static func parse(_ stats: [String: Any]) -> GPUReading? {
        guard let utilization = utilization(stats) else { return nil }

        var used: UInt64?
        var total: UInt64?
        if let usedBytes = IOValue.unsigned(stats["vramUsedBytes"]),
           let freeBytes = IOValue.unsigned(stats["vramFreeBytes"]) {
            used = usedBytes
            total = usedBytes &+ freeBytes
        }
        return GPUReading(utilizationPercent: utilization, vramUsedBytes: used, vramTotalBytes: total)
    }

    /// Accepts a key only when its value is a valid percentage. Other values are discarded, not rescaled.
    private static func utilization(_ stats: [String: Any]) -> Double? {
        for key in ["Device Utilization %", "GPU Core Utilization"] {
            if let value = IOValue.double(stats[key]), (0...100).contains(value) {
                return value
            }
        }
        return nil
    }
}

// MARK: - Disk

enum DiskStatisticsParser {
    /// Sums "Bytes (Read)" and "Bytes (Write)" across the given IOBlockStorageDriver statistics dictionaries.
    /// Returns nil when no driver reports either counter.
    static func counters(from drivers: [[String: Any]]) -> DiskCounters? {
        var read: UInt64 = 0
        var write: UInt64 = 0
        var sawCounter = false

        for stats in drivers {
            if let value = IOValue.unsigned(stats["Bytes (Read)"]) {
                read = read &+ value
                sawCounter = true
            }
            if let value = IOValue.unsigned(stats["Bytes (Write)"]) {
                write = write &+ value
                sawCounter = true
            }
        }
        return sawCounter ? DiskCounters(readBytes: read, writeBytes: write) : nil
    }
}

// MARK: - Battery

enum BatteryParser {
    /// - Parameters:
    ///   - source: one entry from IOPSGetPowerSourceDescription.
    ///   - registry: properties of the AppleSmartBattery service, used for health and cycle count.
    ///     IOPS does not expose either value on every macOS release.
    /// Returns nil when the source is not the internal battery (desktops have none).
    static func parse(source: [String: Any], registry: [String: Any]) -> BatteryReading? {
        guard source["Type"] as? String == "InternalBattery" else { return nil }
        if let present = source["Is Present"] as? Bool, !present { return nil }

        let current = IOValue.double(source["Current Capacity"])
        let maximum = IOValue.double(source["Max Capacity"])
        var percent: Int?
        if let current, let maximum, maximum > 0 {
            // Clamp before converting to Int. A bogus capacity pair can produce a ratio far outside 0...100.
            let ratio = min(max(current / maximum * 100, 0), 100)
            percent = Int(ratio.rounded())
        }

        let charging = source["Is Charging"] as? Bool ?? false
        let onAC = (source["Power Source State"] as? String) == "AC Power"

        // The system reports 0 or a sentinel while it is still estimating, so only plausible values are kept.
        let minutesKey = charging ? "Time to Full Charge" : "Time to Empty"
        var minutes: Int?
        if let value = IOValue.double(source[minutesKey]), value > 0, value < 10_000 {
            minutes = Int(value)
        }

        return BatteryReading(
            currentPercent: percent,
            healthPercent: health(registry: registry),
            cycleCount: IOValue.unsigned(registry["CycleCount"]).flatMap { $0 <= UInt64(Int.max) ? Int($0) : nil },
            isCharging: charging,
            isOnACPower: onAC,
            minutesRemaining: minutes
        )
    }

    /// Power flow in watts from the registry's voltage (mV) and current (mA).
    /// Current is stored as an unsigned 64-bit value that wraps negative while discharging, so it is read as a signed
    /// Int64.
    static func powerWatts(registry: [String: Any]) -> Double? {
        guard let voltageMV = (registry["Voltage"] as? NSNumber)?.int64Value, voltageMV > 0 else { return nil }
        let currentNumber = (registry["InstantAmperage"] as? NSNumber) ?? (registry["Amperage"] as? NSNumber)
        guard let currentMA = currentNumber?.int64Value else { return nil }
        return Double(voltageMV) * Double(currentMA) / 1_000_000
    }

    /// Health = raw maximum capacity / design capacity. Prefers the raw value and falls back to nominal capacity.
    static func health(registry: [String: Any]) -> Double? {
        guard let design = IOValue.double(registry["DesignCapacity"]), design > 0 else { return nil }
        let raw = IOValue.double(registry["AppleRawMaxCapacity"])
            ?? IOValue.double(registry["NominalChargeCapacity"])
        guard let raw, raw > 0 else { return nil }
        return min(100, raw / design * 100)
    }
}
