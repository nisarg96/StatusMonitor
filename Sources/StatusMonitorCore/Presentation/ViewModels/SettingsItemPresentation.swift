import Foundation

/// Display labels for menu bar priorities.
extension MenuBarPriority {
    /// The label for this priority, as the Settings priority picker shows it: "High", "Medium" or "Low".
    public var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/**
 Labels and rules for the menu bar item list and its detail pane.

 Pure, so the Settings views hold no logic.
 */
public enum SettingsItemPresentation {
    /// The six styles shown as chips, in the spec's order.
    private static let chipOrder: [MenuBarItemStyle] = [.value, .stacked, .bars, .sparkline, .ring, .grouped]

    /**
     Returns the display name for a menu bar item.

     - Parameters:
       - item: The menu bar item.
     - Returns: The item's name, such as "Disk I/O".
     */
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

    /**
     Returns the display label for a menu bar item style.

     - Parameters:
       - style: The style.
     - Returns: The style's label, such as "Icon only".
     */
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

    /**
     Returns the style chips for an item.

     Icon only is added for items that support it, such as memory pressure.

     - Parameters:
       - item: The menu bar item.
     - Returns: The styles in chip order, with `.icon` last when the item allows it.
     */
    public static func chipStyles(for item: MetricItemID) -> [MenuBarItemStyle] {
        let allowed = MenuBarItemConfig.allowedStyles(for: item)
        return allowed.contains(.icon) ? chipOrder + [.icon] : chipOrder
    }

    /**
     Returns the unit the alert threshold field is typed in.

     - Parameters:
       - item: The menu bar item.
     - Returns: "MB/s" for network and disk, "°C" for temperature, and "%" for the rest.
     */
    public static func alertUnit(for item: MetricItemID) -> String {
        switch item {
        case .network, .disk: return "MB/s"
        case .thermal: return "°C"
        default: return "%"
        }
    }

    /**
     Returns whether an item offers the hide-when-idle option.

     Only the rate items, network and disk, have it.

     - Parameters:
       - item: The menu bar item.
     - Returns: True for network and disk.
     */
    public static func offersHideWhenIdle(_ item: MetricItemID) -> Bool {
        item == .network || item == .disk
    }

    /**
     Returns the collector behind an item, if the item has one of its own.

     A card with its own collector can be switched off.

     - Parameters:
       - item: The menu bar item.
     - Returns: The collector, or nil for CPU, RAM and network, which have none of their own.
     */
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

    /**
     Converts an idle threshold from bytes per second to KB/s.

     Uses 1024 steps.

     - Parameters:
       - bytes: The threshold, in bytes per second.
     - Returns: The threshold, in KB/s.
     */
    public static func idleKB(fromBytes bytes: Double) -> Double {
        bytes / 1024
    }

    /**
     Converts an idle threshold from KB/s to bytes per second.

     Uses 1024 steps. Negative input is clamped to zero.

     - Parameters:
       - kilobytes: The threshold, in KB/s.
     - Returns: The threshold, in bytes per second, never negative.
     */
    public static func idleBytes(fromKB kilobytes: Double) -> Double {
        max(0, kilobytes) * 1024
    }

    /**
     Returns the Settings list rows: every item except RAM, which is merged into CPU.

     - Parameters:
       - order: The saved item order.
     - Returns: The order without RAM.
     */
    public static func listedItems(order: [MetricItemID]) -> [MetricItemID] {
        order.filter { $0 != .ram }
    }

    /**
     Returns the item order after moving rows, as a SwiftUI `List` `onMove` does.

     RAM is not listed, so it is kept last.

     - Parameters:
       - order: The current item order, including RAM.
       - source: The indices of the listed rows to move.
       - destination: The index the moved rows land before, in the listed rows as they were before the move.
     - Returns: The new item order, ending with RAM.
     */
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
