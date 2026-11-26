import Foundation

/// Glyph builders for the CPU, RAM, GPU, memory pressure, temperature and battery items.
enum MenuBarGlyphItems {
    /**
     Builds the glyph for the CPU item in CPU percent mode.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style.
     */
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

    /**
     Builds the CPU item in RAM mode, showing used RAM in GB.

     The value is coloured by the RAM threshold. The CPU icon stays.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph, or nil until the Mac's physical memory is known.
     */
    static func cpuMemory(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let percent = inputs.ramUsedPercent else { return nil }
        let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: inputs.ramThresholdPercent)
        return .level(symbol: MetricSymbol.cpu, value: Format.gib(inputs.snapshot.memoryUsedBytes), accent: accent)
    }

    /**
     Builds the RAM item.

     The RAM item shows used RAM as a percentage, or in GB for the sparkline style. Its colour follows the RAM
     threshold: orange within 10 points below it, red at it.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil until the Mac's physical memory is known.
     */
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
            let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: inputs.ramThresholdPercent)
            return .level(symbol: MetricSymbol.memory, value: Format.gib(inputs.snapshot.memoryUsedBytes),
                          accent: accent)
        }
    }

    /**
     Builds the GPU item.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil when there is no GPU reading.
     */
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

    /**
     Builds the memory pressure item.

     Icon only by default. Its value style shows the level's label.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph, or nil when there is no memory pressure reading.
     */
    static func memoryPressure(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let level = inputs.snapshot.memoryPressure else { return nil }
        if inputs.style == .icon {
            return .pressure(symbol: MetricSymbol.memoryPressure, level: level)
        }
        return .text(symbol: MetricSymbol.memoryPressure, value: level.label, alert: level != .normal)
    }

    /**
     Builds the temperature item.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil when there is no CPU temperature.
     */
    static func thermal(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let temperature = inputs.snapshot.thermal?.cpuTemperatureC else { return nil }
        let alert = inputs.isAlert(temperature)
        if inputs.style == .ring {
            return .ring(symbol: MetricSymbol.thermal, fraction: min(1, temperature / 110),
                         value: degrees(temperature), alert: alert)
        }
        return .text(symbol: MetricSymbol.thermal, value: degrees(temperature), alert: alert)
    }

    /**
     Formats a temperature as degrees with no unit letter, such as "54°".

     The popover keeps "°C".

     - Parameters:
       - celsius: The temperature, in degrees Celsius.
     - Returns: The temperature rounded to a whole degree, with the degree sign.
     */
    static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }

    /**
     Builds the battery item.

     The battery never alerts, because the bar has no battery threshold.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil when there is no battery charge reading.
     */
    static func battery(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let battery = inputs.snapshot.battery, let percent = battery.currentPercent else { return nil }
        let symbol = MetricSymbol.battery(percent: percent, charging: battery.isCharging)
        if inputs.style == .ring {
            return .ring(symbol: symbol, fraction: Double(percent) / 100, value: "\(percent)%", alert: false)
        }
        return .text(symbol: symbol, value: "\(percent)%", alert: false)
    }
}
