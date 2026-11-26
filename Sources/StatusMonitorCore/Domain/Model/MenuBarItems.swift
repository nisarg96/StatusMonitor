import Foundation

/// One status bar item per metric. Each item is shown or hidden on its own; hiding keeps its position.
public enum MetricItemID: String, CaseIterable, Codable, Sendable {
    /// The CPU item.
    case cpu
    /// The RAM item. It is never shown on its own. See `MetricSettings.isMenuBarItemVisible`.
    case ram
    /// The GPU item.
    case gpu
    /// The memory pressure item.
    case memoryPressure
    /// The network item.
    case network
    /// The disk item.
    case disk
    /// The battery item.
    case battery
    /// The thermal item.
    case thermal
}

/// How important a menu bar item is. Used for ordering and, in a later step, for hiding when the bar is full.
public enum MenuBarPriority: String, CaseIterable, Codable, Sendable, Comparable {
    /// The most important priority.
    case high
    /// The middle priority.
    case medium
    /// The least important priority.
    case low

    /**
     The position of this priority in the ordering. Lower rank is more important.

     - Returns: 0 for high, 1 for medium, and 2 for low.
     */
    public var rank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    /**
     Orders priorities from most to least important.

     - Parameters:
       - lhs: The priority to compare.
       - rhs: The priority to compare against.
     - Returns: True when `lhs` is more important than `rhs`.
     */
    public static func < (lhs: MenuBarPriority, rhs: MenuBarPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

extension MetricSettings {
    /**
     Returns the priority for an item.

     - Parameter item: The item to get the priority for.
     - Returns: The priority the user chose, or the default when the user has not chosen one.
     */
    public func priority(for item: MetricItemID) -> MenuBarPriority {
        menuBarPriorities[item] ?? MenuBarPriorities.defaultPriority(for: item)
    }

    /**
     Reports whether an item should be shown in the menu bar now.

     Items whose collector the Mac lacks, or the user switched off, are never shown. Showing is separate from having a
     value yet: an item with no value shows its icon alone. RAM is merged into the CPU item, so it is never shown on its
     own. Its value appears on the CPU item when the user picks RAM.

     - Parameters:
       - item: The item to check.
       - capabilities: What the Mac supports.
     - Returns: True when the item should be shown.
     */
    public func isMenuBarItemVisible(_ item: MetricItemID, capabilities: MetricCapabilities) -> Bool {
        switch item {
        case .cpu:
            return showCPU
        case .ram:
            return false
        case .network:
            return showNetwork
        case .gpu:
            return isCollectorEnabled(.gpu, capabilities: capabilities) && !hiddenMenuBarItems.contains(.gpu)
        case .memoryPressure:
            return isCollectorEnabled(.memoryPressure, capabilities: capabilities)
                && !hiddenMenuBarItems.contains(.memoryPressure)
        case .disk:
            return isCollectorEnabled(.disk, capabilities: capabilities) && !hiddenMenuBarItems.contains(.disk)
        case .battery:
            return isCollectorEnabled(.battery, capabilities: capabilities)
                && !hiddenMenuBarItems.contains(.battery)
                && isBatteryDetailShown(.menuBarCharge)
        case .thermal:
            return isCollectorEnabled(.thermal, capabilities: capabilities) && !hiddenMenuBarItems.contains(.thermal)
        }
    }
}

/// Default priorities for the menu bar items.
public enum MenuBarPriorities {
    /**
     Returns the starting priority for an item. The user can change every one.

     - Parameter item: The item to get the default priority for.
     - Returns: The default priority.
     */
    public static func defaultPriority(for item: MetricItemID) -> MenuBarPriority {
        switch item {
        case .cpu, .ram: return .high
        case .network, .gpu, .battery: return .medium
        case .memoryPressure, .disk, .thermal: return .low
        }
    }
}
