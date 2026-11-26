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
    /// A text label and one value, with no icon. GPU uses it by default.
    case label(title: String, value: String, alert: Bool)
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
    /// The renderer for each item and state comes from `MenuBarGlyphTable`.
    public static func glyph(
        for item: MetricItemID,
        snapshot: SystemSnapshot,
        config: MenuBarItemConfig,
        history: [HistorySeries: SampleHistory],
        physicalMemoryBytes: UInt64,
        ramThresholdPercent: Int = AutoCleanThreshold.defaultPercent,
        cpuMode: CPUDisplayMode = .percent
    ) -> MenuBarGlyph? {
        // Before the first sample the value is not real, so the item shows its icon alone.
        guard snapshot.isSampled else { return nil }
        let inputs = MenuBarGlyphInputs(
            snapshot: snapshot,
            config: config,
            history: history,
            physicalMemoryBytes: physicalMemoryBytes,
            ramThresholdPercent: ramThresholdPercent,
            cpuMode: cpuMode
        )
        let slot = MenuBarGlyphTable.slot(for: item, cpuMode: cpuMode)
        return MenuBarGlyphTable.renderers[slot]?(inputs)
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
