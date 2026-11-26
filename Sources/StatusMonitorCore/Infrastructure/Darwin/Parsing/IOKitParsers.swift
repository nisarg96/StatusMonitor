import Foundation

/// Reads an IOKit numeric value defensively. Anything that is not a non-negative finite number is nil.
enum IOValue {
    /// 2^64 as a Double. Any value at or above it does not fit in a UInt64, and converting it would trap.
    private static let uint64Limit: Double = 18_446_744_073_709_551_616

    /**
     Converts an IOKit value to a finite Double.

     Accepts `NSNumber`, `Double` and `Int`.

     - Parameters:
       - value: The raw value from an IOKit dictionary.
     - Returns: The number, or nil for any other type or a non-finite value.
     */
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

    /**
     Converts an IOKit value to a UInt64.

     - Parameters:
       - value: The raw value from an IOKit dictionary.
     - Returns: The value, or nil when it is negative, non-finite, or 2^64 or larger.
     */
    static func unsigned(_ value: Any?) -> UInt64? {
        guard let number = double(value), number >= 0, number < uint64Limit else { return nil }
        return UInt64(number)
    }
}

// MARK: - GPU

/// Parses the IOAccelerator `PerformanceStatistics` dictionary, keeping the key-name knowledge out of the adapter.
enum GPUStatisticsParser {
    /**
     Builds a GPU reading from an IOAccelerator's `PerformanceStatistics` dictionary.

     VRAM is reported only when both used and free are present, because total = used + free.

     - Parameters:
       - stats: The `PerformanceStatistics` dictionary.
     - Returns: The reading, or nil when there is no usable utilization value.
     */
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

/// Sums disk byte counters from IOBlockStorageDriver statistics, keeping the key-name knowledge out of the adapter.
enum DiskStatisticsParser {
    /**
     Sums `Bytes (Read)` and `Bytes (Write)` across the given IOBlockStorageDriver statistics dictionaries.

     - Parameters:
       - drivers: One statistics dictionary per driver.
     - Returns: The totals in bytes, or nil when no driver reports either counter.
     */
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

/// Parses IOPS power source and AppleSmartBattery registry data, keeping the key-name knowledge out of the adapter.
enum BatteryParser {
    /**
     Builds a battery reading from one IOPS power source.

     The percentage is clamped to 0...100 before conversion to Int, because a bogus capacity pair can produce a
     ratio far outside that range. Minutes remaining are kept only when they fall between 0 and 10,000, because the
     system reports 0 or a sentinel while it is still estimating.

     - Parameters:
       - source: One entry from `IOPSGetPowerSourceDescription`.
       - registry: Properties of the AppleSmartBattery service, used for health and cycle count.
         IOPS does not expose either value on every macOS release.
     - Returns: The reading, or nil when the source is not the internal battery (desktops have none) or is not present.
     */
    static func parse(source: [String: Any], registry: [String: Any]) -> BatteryReading? {
        guard source["Type"] as? String == "InternalBattery" else { return nil }
        if let present = source["Is Present"] as? Bool, !present { return nil }

        let current = IOValue.double(source["Current Capacity"])
        let maximum = IOValue.double(source["Max Capacity"])
        var percent: Int?
        if let current, let maximum, maximum > 0 {
            let ratio = min(max(current / maximum * 100, 0), 100)
            percent = Int(ratio.rounded())
        }

        let charging = source["Is Charging"] as? Bool ?? false
        let onAC = (source["Power Source State"] as? String) == "AC Power"

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

    /**
     Computes battery power flow in watts from the registry's voltage and current.

     Voltage is in millivolts and current in milliamps. Current is stored as an unsigned 64-bit value that wraps
     negative while discharging, so it is read as a signed Int64.

     - Parameters:
       - registry: Properties of the AppleSmartBattery service.
     - Returns: Watts, positive while charging and negative while discharging. Nil when voltage or current is unknown.
     */
    static func powerWatts(registry: [String: Any]) -> Double? {
        guard let voltageMV = (registry["Voltage"] as? NSNumber)?.int64Value, voltageMV > 0 else { return nil }
        let currentNumber = (registry["InstantAmperage"] as? NSNumber) ?? (registry["Amperage"] as? NSNumber)
        guard let currentMA = currentNumber?.int64Value else { return nil }
        return Double(voltageMV) * Double(currentMA) / 1_000_000
    }

    /**
     Computes battery health as a percentage of design capacity.

     Health = raw maximum capacity / design capacity. Prefers the raw value and falls back to nominal capacity.

     - Parameters:
       - registry: Properties of the AppleSmartBattery service.
     - Returns: Health in percent, capped at 100, or nil when design capacity or both raw values are unusable.
     */
    static func health(registry: [String: Any]) -> Double? {
        guard let design = IOValue.double(registry["DesignCapacity"]), design > 0 else { return nil }
        let raw = IOValue.double(registry["AppleRawMaxCapacity"])
            ?? IOValue.double(registry["NominalChargeCapacity"])
        guard let raw, raw > 0 else { return nil }
        return min(100, raw / design * 100)
    }
}
