import Foundation

/// How the CPU item is rendered in the status bar.
public enum CPUDisplayMode: String, CaseIterable, Equatable, Sendable {
    /// Busy CPU percentage, e.g. "CPU 12%".
    case percent
    /// Used RAM in GB, e.g. "RAM 3.2 GB".
    /// Interpretation: "GB" means used memory (app + wired + compressed), not CPU load.
    /// The bar label is "RAM" so the number is not mistaken for CPU.
    case memoryGB
}

/// Which colour theme the popover and Settings window use. System follows the Mac's appearance.
public enum AppearanceMode: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

/// The individual battery readings the user can hide. Each one is shown by default.
public enum BatteryDetail: String, CaseIterable, Codable, Sendable {
    /// The charge row in the popover.
    case charge
    /// Charging or discharging power in watts.
    case powerFlow
    /// The battery percentage in the menu bar. Separate from the popover row, so each can be hidden on its own.
    case menuBarCharge
    case health
    case cycles
    case powerState
    case lowPowerMode
    case timeRemaining
}

/// Items that can appear in the menu bar. CPU and network keep their own on/off switches (`showCPU`, `showNetwork`).
public enum MenuBarItem: String, CaseIterable, Codable, Sendable {
    case ram
    case gpu
    case memoryPressure
    case disk
    case battery
    case thermal

    /// The bar is crowded, so these start hidden. Everything else starts visible.
    public static let defaultHidden: Set<MenuBarItem> = [.memoryPressure, .disk, .battery, .thermal]
}

/// User configuration. Pure value type; persistence is an infrastructure concern.
public struct MetricSettings: Equatable, Sendable {
    public var showCPU: Bool
    public var cpuMode: CPUDisplayMode
    public var showNetwork: Bool
    /// Off by default. When on, loopback (lo0) traffic is counted.
    public var includeLoopback: Bool
    /// Interface names to count. Empty = all active interfaces.
    public var allowedInterfaces: Set<String>
    /// Explicit user choices for optional collectors. A missing entry means "on, if the Mac supports it".
    public var collectorOverrides: [CollectorKind: Bool]
    /// Battery readings the user has hidden. Empty by default, so every battery detail is shown.
    public var hiddenBatteryDetails: Set<BatteryDetail>
    /// Items hidden from the menu bar. They stay available in the popover.
    public var hiddenMenuBarItems: Set<MenuBarItem>
    /// User-chosen priority per status bar item. A missing entry uses `MenuBarPriorities.defaultPriority`.
    public var menuBarPriorities: [MetricItemID: MenuBarPriority]
    /// Off by default. When on, Standard Clean runs automatically once used RAM reaches the threshold.
    public var autoCleanEnabled: Bool
    /// Used-RAM percentage that triggers Auto Clean. Always a slider stop from 70 to 100.
    public var autoCleanThresholdPercent: Int
    /// Per-item appearance and behaviour. A missing entry uses `MenuBarItemConfig.defaults`.
    public var menuBarItemConfigs: [MetricItemID: MenuBarItemConfig]
    /// The order of items in the Settings list, which is also the tie-break inside each priority level.
    public var menuBarOrder: [MetricItemID]
    /// Light, dark or follow the system. Applies to the popover and Settings window.
    public var appearance: AppearanceMode

    public init(
        showCPU: Bool = true,
        cpuMode: CPUDisplayMode = .percent,
        showNetwork: Bool = true,
        includeLoopback: Bool = false,
        allowedInterfaces: Set<String> = [],
        collectorOverrides: [CollectorKind: Bool] = [:],
        hiddenBatteryDetails: Set<BatteryDetail> = [],
        hiddenMenuBarItems: Set<MenuBarItem> = MenuBarItem.defaultHidden,
        menuBarPriorities: [MetricItemID: MenuBarPriority] = [:],
        autoCleanEnabled: Bool = false,
        autoCleanThresholdPercent: Int = AutoCleanThreshold.defaultPercent,
        menuBarItemConfigs: [MetricItemID: MenuBarItemConfig] = [:],
        menuBarOrder: [MetricItemID] = MetricItemID.allCases,
        appearance: AppearanceMode = .system
    ) {
        self.appearance = appearance
        self.menuBarOrder = menuBarOrder
        self.menuBarItemConfigs = menuBarItemConfigs
        self.autoCleanEnabled = autoCleanEnabled
        self.autoCleanThresholdPercent = AutoCleanThreshold.snapped(autoCleanThresholdPercent)
        self.menuBarPriorities = menuBarPriorities
        self.showCPU = showCPU
        self.cpuMode = cpuMode
        self.showNetwork = showNetwork
        self.includeLoopback = includeLoopback
        self.allowedInterfaces = allowedInterfaces
        self.collectorOverrides = collectorOverrides
        self.hiddenBatteryDetails = hiddenBatteryDetails
        self.hiddenMenuBarItems = hiddenMenuBarItems
    }

    public func isBatteryDetailShown(_ detail: BatteryDetail) -> Bool {
        !hiddenBatteryDetails.contains(detail)
    }

    public func isMenuBarItemShown(_ item: MenuBarItem) -> Bool {
        !hiddenMenuBarItems.contains(item)
    }

    /// A collector runs only when the Mac supports it AND the user has not switched it off.
    /// Unsupported collectors are always off, even if the user once enabled them. That covers
    /// hardware changes, such as an external display or a disk going away.
    public func isCollectorEnabled(_ kind: CollectorKind, capabilities: MetricCapabilities) -> Bool {
        capabilities.supports(kind) && (collectorOverrides[kind] ?? true)
    }

    public func enabledCollectors(capabilities: MetricCapabilities) -> Set<CollectorKind> {
        Set(CollectorKind.allCases.filter { isCollectorEnabled($0, capabilities: capabilities) })
    }
}
