import Foundation

/// Glyph builders for the CPU, RAM, GPU, memory pressure, temperature and battery items.
enum MenuBarGlyphItems {
    static func cpu(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        let value = inputs.snapshot.cpuPercent
        let alert = inputs.isAlert(value)
        switch inputs.style {
        case .bars:
            return .bars(symbol: MetricSymbol.cpu, levels: inputs.levels(.cpu, percentScale: true), alert: alert)
        case .sparkline:
            return .sparkline(symbol: MetricSymbol.cpu, levels: inputs.levels(.cpu, percentScale: true),
                              value: Format.percent(value), alert: alert)
        case .ring:
            return .ring(symbol: MetricSymbol.cpu, fraction: value / 100, value: Format.percent(value), alert: alert)
        default:
            return .text(symbol: MetricSymbol.cpu, value: Format.percent(value), alert: alert)
        }
    }

    /// CPU item in RAM mode: used RAM in GB, coloured by the RAM threshold. The CPU icon stays.
    static func cpuMemory(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let percent = inputs.ramUsedPercent else { return nil }
        let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: inputs.ramThresholdPercent)
        return .level(symbol: MetricSymbol.cpu, value: Format.gib(inputs.snapshot.memoryUsedBytes), accent: accent)
    }

    static func ram(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let percent = inputs.ramUsedPercent else { return nil }
        let alert = inputs.isAlert(percent)
        switch inputs.style {
        case .ring:
            return .ring(symbol: MetricSymbol.memory, fraction: percent / 100,
                         value: Format.percent(percent), alert: alert)
        case .sparkline:
            return .sparkline(symbol: MetricSymbol.memory, levels: inputs.levels(.ram, percentScale: true),
                              value: Format.gib(inputs.snapshot.memoryUsedBytes), alert: alert)
        default:
            // RAM follows the RAM threshold: orange within 10 points below it, red at it.
            let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: inputs.ramThresholdPercent)
            return .level(symbol: MetricSymbol.memory, value: Format.gib(inputs.snapshot.memoryUsedBytes),
                          accent: accent)
        }
    }

    static func gpu(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let gpu = inputs.snapshot.gpu else { return nil }
        let value = gpu.utilizationPercent
        let alert = inputs.isAlert(value)
        switch inputs.style {
        case .ring:
            return .ring(symbol: MetricSymbol.gpu, fraction: value / 100, value: Format.percent(value), alert: alert)
        case .sparkline:
            return .sparkline(symbol: MetricSymbol.gpu, levels: inputs.levels(.gpu, percentScale: true),
                              value: Format.percent(value), alert: alert)
        default:
            return .label(title: "GPU", value: Format.percent(value), alert: alert)
        }
    }

    /// Memory pressure: icon only by default. Its value style shows the level's label.
    static func memoryPressure(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let level = inputs.snapshot.memoryPressure else { return nil }
        if inputs.style == .icon {
            return .pressure(symbol: MetricSymbol.memoryPressure, level: level)
        }
        return .text(symbol: MetricSymbol.memoryPressure, value: level.label, alert: level != .normal)
    }

    static func thermal(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let temperature = inputs.snapshot.thermal?.cpuTemperatureC else { return nil }
        let alert = inputs.isAlert(temperature)
        if inputs.style == .ring {
            return .ring(symbol: MetricSymbol.thermal, fraction: min(1, temperature / 110),
                         value: degrees(temperature), alert: alert)
        }
        return .text(symbol: MetricSymbol.thermal, value: degrees(temperature), alert: alert)
    }

    /// Degrees with no unit letter, as the menu bar shows temperature. The popover keeps "°C".
    static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }

    /// Battery never alerts: it has no threshold in the bar.
    static func battery(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let battery = inputs.snapshot.battery, let percent = battery.currentPercent else { return nil }
        let symbol = MetricSymbol.battery(percent: percent, charging: battery.isCharging)
        if inputs.style == .ring {
            return .ring(symbol: symbol, fraction: Double(percent) / 100, value: "\(percent)%", alert: false)
        }
        return .text(symbol: symbol, value: "\(percent)%", alert: false)
    }
}
