import Foundation

/// Fixed-length history of recent values, oldest first. Used for sparklines and bars.
public struct SampleHistory: Equatable, Sendable {
    public static let capacity = 60

    public private(set) var values: [Double] = []

    public init() {}

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > Self.capacity {
            values.removeFirst(values.count - Self.capacity)
        }
    }
}

/// A pure description of what one status bar item shows. The AppKit adapter draws it; no drawing happens here.
public enum MenuBarGlyph: Equatable, Sendable {
    /// Icon and one value.
    case text(symbol: String, value: String, alert: Bool)
    /// Two values stacked: up on top, down underneath.
    case stacked(symbol: String, top: String, bottom: String, alert: Bool)
    /// Bars scaled 0...1, oldest first.
    case bars(symbol: String, levels: [Double], alert: Bool)
    /// A line through recent samples (scaled 0...1), plus the current value.
    case sparkline(symbol: String, levels: [Double], value: String, alert: Bool)
    /// A ring filled to `fraction` (0...1), plus the value.
    case ring(symbol: String, fraction: Double, value: String, alert: Bool)
    /// Value with a colour state: orange as a warning, red when critical. Used for RAM against its threshold.
    case level(symbol: String, value: String, accent: ReadoutAccent)
    /// Memory pressure as an icon only. Warning adds a triangle and bold; critical fills the item and adds "!".
    case pressure(symbol: String, level: MemoryPressureLevel)
}

/// Series names for history. Network and disk have two directions, so each gets its own series.
public enum HistorySeries: String, CaseIterable, Sendable {
    case cpu, ram, gpu, networkDown, networkUp, diskRead, diskWrite, temperature
}

public enum MenuBarGlyphBuilder {
    /// Builds the glyph for one item, or nil when the item has no value yet, so the caller can show its icon alone.
    public static func glyph(
        for item: MetricItemID,
        snapshot: SystemSnapshot,
        config: MenuBarItemConfig,
        history: [HistorySeries: SampleHistory],
        physicalMemoryBytes: UInt64,
        ramThresholdPercent: Int = AutoCleanThreshold.defaultPercent,
        cpuMode: CPUDisplayMode = .percent
    ) -> MenuBarGlyph? {
        switch item {
        case .cpu where cpuMode == .memoryGB:
            // The combined CPU item shows RAM in GB when the user picks it. The CPU icon stays, and RAM's threshold colours it.
            guard physicalMemoryBytes > 0 else { return nil }
            let percent = Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100
            let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: ramThresholdPercent)
            return .level(symbol: MetricSymbol.cpu, value: Format.gib(snapshot.memoryUsedBytes), accent: accent)

        case .cpu:
            let value = snapshot.cpuPercent
            let alert = isAlert(value, config)
            switch config.style {
            case .bars:
                return .bars(symbol: MetricSymbol.cpu, levels: levels(history[.cpu], percentScale: true), alert: alert)
            case .sparkline:
                return .sparkline(symbol: MetricSymbol.cpu, levels: levels(history[.cpu], percentScale: true),
                                  value: Format.percent(value), alert: alert)
            case .ring:
                return .ring(symbol: MetricSymbol.cpu, fraction: value / 100, value: Format.percent(value), alert: alert)
            default:
                return .text(symbol: MetricSymbol.cpu, value: Format.percent(value), alert: alert)
            }

        case .ram:
            // RAM is merged into the CPU item, so it has no bar item of its own.
            guard physicalMemoryBytes > 0 else { return nil }
            let percent = Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100
            let alert = isAlert(percent, config)
            switch config.style {
            case .ring:
                return .ring(symbol: MetricSymbol.memory, fraction: percent / 100,
                             value: Format.percent(percent), alert: alert)
            case .sparkline:
                return .sparkline(symbol: MetricSymbol.memory, levels: levels(history[.ram], percentScale: true),
                                  value: Format.gib(snapshot.memoryUsedBytes), alert: alert)
            default:
                // RAM follows the RAM threshold: orange within 10 points below it, red at it.
                let accent = RAMAlertLevel.level(usedPercent: percent, thresholdPercent: ramThresholdPercent)
                return .level(symbol: MetricSymbol.memory, value: Format.gib(snapshot.memoryUsedBytes), accent: accent)
            }

        case .gpu:
            guard let gpu = snapshot.gpu else { return nil }
            let value = gpu.utilizationPercent
            let alert = isAlert(value, config)
            switch config.style {
            case .ring:
                return .ring(symbol: MetricSymbol.gpu, fraction: value / 100, value: Format.percent(value), alert: alert)
            case .sparkline:
                return .sparkline(symbol: MetricSymbol.gpu, levels: levels(history[.gpu], percentScale: true),
                                  value: Format.percent(value), alert: alert)
            default:
                return .text(symbol: MetricSymbol.gpu, value: Format.percent(value), alert: alert)
            }

        case .network:
            let down = snapshot.downBps
            let up = snapshot.upBps
            let alert = isAlert(max(down, up), config)
            switch config.style {
            case .stacked, .grouped:
                return .stacked(symbol: MetricSymbol.network,
                                top: "↑ \(Format.rate(up))", bottom: "↓ \(Format.rate(down))", alert: alert)
            case .sparkline:
                return .sparkline(symbol: MetricSymbol.network,
                                  levels: levels(history[.networkDown], percentScale: false),
                                  value: "↓ \(Format.rate(down))", alert: alert)
            default:
                return .text(symbol: MetricSymbol.network, value: "↓ \(Format.rate(down))", alert: alert)
            }

        case .disk:
            guard let disk = snapshot.disk else { return nil }
            let alert = isAlert(max(disk.readBps, disk.writeBps), config)
            switch config.style {
            case .stacked, .grouped:
                return .stacked(symbol: MetricSymbol.disk,
                                top: "↑ \(Format.rate(disk.writeBps))", bottom: "↓ \(Format.rate(disk.readBps))", alert: alert)
            case .sparkline:
                return .sparkline(symbol: MetricSymbol.disk, levels: levels(history[.diskRead], percentScale: false),
                                  value: "↓ \(Format.rate(disk.readBps))", alert: alert)
            default:
                return .text(symbol: MetricSymbol.disk, value: "↓ \(Format.rate(disk.readBps))", alert: alert)
            }

        case .memoryPressure:
            guard let level = snapshot.memoryPressure else { return nil }
            if config.style == .icon {
                return .pressure(symbol: MetricSymbol.memoryPressure, level: level)
            }
            return .text(symbol: MetricSymbol.memoryPressure, value: level.label, alert: level != .normal)

        case .thermal:
            guard let temperature = snapshot.thermal?.cpuTemperatureC else { return nil }
            let alert = isAlert(temperature, config)
            if config.style == .ring {
                return .ring(symbol: MetricSymbol.thermal, fraction: min(1, temperature / 110),
                             value: Format.celsius(temperature), alert: alert)
            }
            return .text(symbol: MetricSymbol.thermal, value: Format.celsius(temperature), alert: alert)

        case .battery:
            guard let battery = snapshot.battery, let percent = battery.currentPercent else { return nil }
            let symbol = MetricSymbol.battery(percent: percent, charging: battery.isCharging)
            if config.style == .ring {
                return .ring(symbol: symbol, fraction: Double(percent) / 100, value: "\(percent)%", alert: false)
            }
            return .text(symbol: symbol, value: "\(percent)%", alert: false)
        }
    }

    /// Alerts apply only when the user set a threshold for the item.
    static func isAlert(_ value: Double, _ config: MenuBarItemConfig) -> Bool {
        guard let threshold = config.alertAbove else { return false }
        return value > threshold
    }

    /// Maps history to 0...1. Percent series use a fixed 0...100 scale; rate series scale to their own peak,
    /// so a quiet network still shows its shape. Empty history gives no levels.
    static func levels(_ history: SampleHistory?, percentScale: Bool) -> [Double] {
        guard let values = history?.values, !values.isEmpty else { return [] }
        if percentScale {
            return values.map { min(1, max(0, $0 / 100)) }
        }
        let peak = values.max() ?? 0
        guard peak > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / peak }
    }

    /// Whether an item should be hidden right now because its value is idle. Only applies when the user asked for it.
    public static func isIdle(_ item: MetricItemID, snapshot: SystemSnapshot, config: MenuBarItemConfig) -> Bool {
        guard config.hideWhenIdle else { return false }
        switch item {
        case .network: return max(snapshot.downBps, snapshot.upBps) < config.idleBelow
        case .disk:
            guard let disk = snapshot.disk else { return false }
            return max(disk.readBps, disk.writeBps) < config.idleBelow
        default: return false
        }
    }
}
