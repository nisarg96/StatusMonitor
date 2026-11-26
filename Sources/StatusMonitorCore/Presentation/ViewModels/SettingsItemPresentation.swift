import Foundation

extension MenuBarPriority {
    /// "High", "Medium" or "Low", as the Settings priority picker shows them.
    public var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// Labels and rules for the menu bar item list and its detail pane. Pure, so the Settings views hold no logic.
public enum SettingsItemPresentation {
    /// The six styles shown as chips, in the spec's order.
    private static let chipOrder: [MenuBarItemStyle] = [.value, .stacked, .bars, .sparkline, .ring, .grouped]

    public static func name(for item: MetricItemID) -> String {
        switch item {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .gpu: return "GPU"
        case .memoryPressure: return "Memory pressure"
        case .network: return "Network"
        case .disk: return "Disk I/O"
        case .battery: return "Battery"
        case .thermal: return "Temperature"
        }
    }

    public static func styleLabel(_ style: MenuBarItemStyle) -> String {
        switch style {
        case .value: return "Value"
        case .stacked: return "Stacked"
        case .bars: return "Bars"
        case .sparkline: return "Sparkline"
        case .ring: return "Ring"
        case .grouped: return "Grouped"
        case .icon: return "Icon only"
        }
    }

    /// The style chips for an item. Icon only is added for items that support it, such as memory pressure.
    public static func chipStyles(for item: MetricItemID) -> [MenuBarItemStyle] {
        let allowed = MenuBarItemConfig.allowedStyles(for: item)
        return allowed.contains(.icon) ? chipOrder + [.icon] : chipOrder
    }

    /// The unit the alert threshold is typed in.
    public static func alertUnit(for item: MetricItemID) -> String {
        switch item {
        case .network, .disk: return "MB/s"
        case .thermal: return "°C"
        default: return "%"
        }
    }

    /// Only the rate items can hide while idle.
    public static func offersHideWhenIdle(_ item: MetricItemID) -> Bool {
        item == .network || item == .disk
    }

    /// The collector behind an item, if the item has one of its own (its card can be switched off).
    public static func collector(for item: MetricItemID) -> CollectorKind? {
        switch item {
        case .gpu: return .gpu
        case .memoryPressure: return .memoryPressure
        case .disk: return .disk
        case .battery: return .battery
        case .thermal: return .thermal
        case .cpu, .ram, .network: return nil
        }
    }

    /// The idle threshold is typed in KB/s, using 1024 steps, and stored in bytes per second.
    public static func idleKB(fromBytes bytes: Double) -> Double {
        bytes / 1024
    }

    public static func idleBytes(fromKB kilobytes: Double) -> Double {
        max(0, kilobytes) * 1024
    }

    /// The list rows: every item except RAM, which is merged into CPU.
    public static func listedItems(order: [MetricItemID]) -> [MetricItemID] {
        order.filter { $0 != .ram }
    }

    /// Moves the rows at `source` so they land before the row at `destination` (a List onMove), and keeps RAM last.
    public static func reordered(_ order: [MetricItemID], moving source: [Int], to destination: Int) -> [MetricItemID] {
        let listed = listedItems(order: order)
        let moving = source.sorted().map { listed[$0] }
        let remaining = listed.indices.filter { !source.contains($0) }.map { listed[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        var result = remaining
        result.insert(contentsOf: moving, at: insertAt)
        return result + [.ram]
    }
}
