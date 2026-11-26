import Foundation

/// Builds the popover rows. A row exists only when its value exists, so nothing is shown as zero or N/A.
public enum ReadoutBuilder {
    /// Shown in place of a value before the first sample.
    public static let emptyValue = "--"

    public static func rows(for snapshot: SystemSnapshot, settings: MetricSettings) -> [ReadoutRow] {
        var rows: [ReadoutRow] = []
        let sampled = snapshot.isSampled

        if settings.showCPU {
            rows.append(ReadoutRow(
                id: "cpu", symbol: MetricSymbol.cpu, label: "CPU",
                value: sampled ? Format.percent(snapshot.cpuPercent) : emptyValue))
            rows.append(ReadoutRow(
                id: "ram", symbol: MetricSymbol.memory, label: "Used RAM",
                value: sampled ? Format.gib(snapshot.memoryUsedBytes) : emptyValue,
                accent: ramAccent(snapshot, settings: settings)
            ))
        }
        if settings.showNetwork {
            rows.append(ReadoutRow(
                id: "down", symbol: MetricSymbol.download, label: "Download",
                value: sampled ? Format.rate(snapshot.downBps) : emptyValue))
            rows.append(ReadoutRow(
                id: "up", symbol: MetricSymbol.upload, label: "Upload",
                value: sampled ? Format.rate(snapshot.upBps) : emptyValue))
        }

        if let gpu = snapshot.gpu {
            rows.append(contentsOf: gpuRows(gpu))
        }

        if let level = snapshot.memoryPressure {
            rows.append(ReadoutRow(
                id: "pressure", collector: .memoryPressure, symbol: MetricSymbol.memoryPressure,
                label: "Memory pressure", value: level.label, accent: accent(for: level)
            ))
        }

        if let disk = snapshot.disk {
            rows.append(ReadoutRow(
                id: "diskRead", collector: .disk, symbol: MetricSymbol.download, label: "Read",
                value: Format.rate(disk.readBps)))
            rows.append(ReadoutRow(
                id: "diskWrite", collector: .disk, symbol: MetricSymbol.upload, label: "Write",
                value: Format.rate(disk.writeBps)))
        }

        if let battery = snapshot.battery {
            // Each battery row is filtered by its own detail toggle.
            rows.append(contentsOf: batteryRows(battery).filter { row in
                guard let detail = batteryDetail(forRowID: row.id) else { return true }
                return settings.isBatteryDetailShown(detail)
            })
        }

        if let thermal = snapshot.thermal {
            rows.append(contentsOf: thermalRows(thermal))
        }

        return rows
    }

    private static func gpuRows(_ gpu: GPUReading) -> [ReadoutRow] {
        var rows = [ReadoutRow(
            id: "gpu", collector: .gpu, symbol: MetricSymbol.gpu, label: "GPU",
            value: Format.percent(gpu.utilizationPercent)
        )]
        if let used = gpu.vramUsedBytes, let total = gpu.vramTotalBytes, total > 0 {
            rows.append(ReadoutRow(
                id: "vram", collector: .gpu, symbol: MetricSymbol.memory, label: "VRAM",
                value: "\(Format.gib(used)) / \(Format.gib(total))"
            ))
        }
        return rows
    }

    private static func thermalRows(_ thermal: ThermalReading) -> [ReadoutRow] {
        var rows: [ReadoutRow] = []
        if let temperature = thermal.cpuTemperatureC {
            rows.append(ReadoutRow(
                id: "temp", collector: .thermal, symbol: MetricSymbol.thermal,
                label: "CPU temp", value: Format.celsius(temperature)
            ))
        }
        for fan in thermal.fans {
            rows.append(ReadoutRow(
                id: "fan\(fan.index)", collector: .thermal, symbol: MetricSymbol.fan,
                label: "Fan \(fan.index + 1)", value: "\(fan.rpm) RPM"
            ))
        }
        return rows
    }

    /// Colour for used RAM, from the RAM threshold. Nil when total RAM is unknown, so no colour is guessed.
    static func ramAccent(_ snapshot: SystemSnapshot, settings: MetricSettings) -> ReadoutAccent? {
        guard snapshot.isSampled, let percent = RAMAlertLevel.usedPercent(
            usedBytes: snapshot.memoryUsedBytes,
            physicalBytes: ProcessInfo.processInfo.physicalMemory
        ) else { return nil }
        return RAMAlertLevel.level(usedPercent: percent, thresholdPercent: settings.autoCleanThresholdPercent)
    }

    /// Maps a battery row id to the detail toggle that controls it.
    static func batteryDetail(forRowID id: String) -> BatteryDetail? {
        switch id {
        case "batt": return .charge
        case "health": return .health
        case "cycles": return .cycles
        case "power": return .powerState
        case "lpm": return .lowPowerMode
        case "flow": return .powerFlow
        case "time": return .timeRemaining
        default: return nil
        }
    }

    private static func batteryRows(_ battery: BatteryReading) -> [ReadoutRow] {
        var rows: [ReadoutRow] = []
        if let percent = battery.currentPercent {
            rows.append(ReadoutRow(
                id: "batt", collector: .battery,
                symbol: MetricSymbol.battery(percent: percent, charging: battery.isCharging),
                label: "Charge", value: "\(percent)%"
            ))
        }
        if let health = battery.healthPercent {
            rows.append(ReadoutRow(
                id: "health", collector: .battery, symbol: "heart.fill",
                label: "Health", value: "\(Int(health.rounded()))%"
            ))
        }
        if let cycles = battery.cycleCount {
            rows.append(ReadoutRow(
                id: "cycles", collector: .battery, symbol: "arrow.triangle.2.circlepath",
                label: "Cycles", value: "\(cycles)"
            ))
        }
        rows.append(ReadoutRow(
            id: "power", collector: .battery,
            symbol: battery.isCharging ? "bolt.fill" : (battery.isOnACPower ? "powerplug.fill" : "battery.0percent"),
            label: "Power",
            value: battery.isCharging ? "Charging" : (battery.isOnACPower ? "AC power" : "On battery")
        ))
        rows.append(ReadoutRow(
            id: "lpm", collector: .battery, symbol: "leaf.fill",
            label: "Low Power Mode", value: battery.isLowPowerMode ? "On" : "Off"
        ))
        if let watts = battery.powerWatts {
            rows.append(ReadoutRow(
                id: "flow", collector: .battery,
                symbol: watts >= 0 ? "arrow.up.circle" : "arrow.down.circle",
                label: watts >= 0 ? "Charging" : "Discharging",
                value: Format.watts(watts)
            ))
        }
        if let minutes = battery.minutesRemaining {
            rows.append(ReadoutRow(
                id: "time", collector: .battery, symbol: "clock",
                label: battery.isCharging ? "Time to full" : "Time left",
                value: Format.duration(minutes: minutes)
            ))
        }
        return rows
    }

    private static func accent(for level: MemoryPressureLevel) -> ReadoutAccent {
        switch level {
        case .normal: return .normal
        case .warning: return .warning
        case .critical: return .critical
        }
    }
}
