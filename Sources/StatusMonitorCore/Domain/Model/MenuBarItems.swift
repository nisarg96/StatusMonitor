import Foundation

/// One status bar item per metric. Each item is shown or hidden on its own; hiding keeps its position.
public enum MetricItemID: String, CaseIterable, Codable, Sendable {
    case cpu
    case ram
    case gpu
    case memoryPressure
    case network
    case disk
    case battery
    case thermal
}

/// How important a menu bar item is. Used for ordering and, in a later step, for hiding when the bar is full.
public enum MenuBarPriority: String, CaseIterable, Codable, Sendable, Comparable {
    case high
    case medium
    case low

    /// Lower rank is more important.
    public var rank: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    public static func < (lhs: MenuBarPriority, rhs: MenuBarPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

extension MetricSettings {
    /// The priority the user chose for this item, or its default.
    public func priority(for item: MetricItemID) -> MenuBarPriority {
        menuBarPriorities[item] ?? MenuBarPriorities.defaultPriority(for: item)
    }

    /// Whether this item should be shown in the menu bar now. Pure, so it is testable.
    /// Items whose collector the Mac lacks, or the user switched off, are never shown.
    /// Showing is separate from having a value yet: an item with no value shows its icon alone.
    public func isMenuBarItemVisible(_ item: MetricItemID, capabilities: MetricCapabilities) -> Bool {
        switch item {
        case .cpu:
            return showCPU
        case .ram:
            // RAM is merged into the CPU item. Its value shows there when the user picks RAM.
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

public enum MenuBarPriorities {
    /// Starting priorities. The user can change every one.
    public static func defaultPriority(for item: MetricItemID) -> MenuBarPriority {
        switch item {
        case .cpu, .ram: return .high
        case .network, .gpu, .battery: return .medium
        case .memoryPressure, .disk, .thermal: return .low
        }
    }
}
