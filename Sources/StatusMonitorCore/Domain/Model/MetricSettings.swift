import Foundation

/// How the CPU item is rendered in the status bar.
public enum CPUDisplayMode: String, CaseIterable, Equatable, Sendable {
    /// Busy CPU percentage, e.g. "CPU 12%".
    case percent
    /**
     Used RAM in GiB (1024^3 bytes), shown with the label "GB", e.g. "RAM 3.2 GB".

     "GB" means used memory (app + wired + compressed), not CPU load. The bar label is "RAM" so the number is not
     mistaken for CPU.
     */
    case memoryGB
}

/// Which colour theme the popover and Settings window use. System follows the Mac's appearance.
public enum AppearanceMode: String, CaseIterable, Codable, Sendable {
    /// Follows the Mac's appearance.
    case system
    /// Always uses the light theme.
    case light
    /// Always uses the dark theme.
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
    /// The battery health percentage.
    case health
    /// The battery cycle count.
    case cycles
    /// Whether the battery is charging, and whether the Mac is on AC power.
    case powerState
    /// The System Low Power Mode status.
    case lowPowerMode
    /// The estimated time to empty or to full.
    case timeRemaining
}

/// Items that can appear in the menu bar. CPU and network keep their own on/off switches (`showCPU`, `showNetwork`).
public enum MenuBarItem: String, CaseIterable, Codable, Sendable {
    /// The RAM item.
    case ram
    /// The GPU item.
    case gpu
    /// The memory pressure item.
    case memoryPressure
    /// The disk item.
    case disk
    /// The battery item.
    case battery
    /// The thermal item.
    case thermal

    /// The bar is crowded, so these start hidden. Everything else starts visible.
    public static let defaultHidden: Set<MenuBarItem> = [.memoryPressure, .disk, .battery, .thermal]
}

/// User configuration. Pure value type; persistence is an infrastructure concern.
public struct MetricSettings: Equatable, Sendable {
    /// Whether the CPU item is shown in the menu bar.
    public var showCPU: Bool
    /// How the CPU item shows its value.
    public var cpuMode: CPUDisplayMode
    /// Whether the network item is shown in the menu bar.
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

    /**
     Creates settings. Every parameter has a default.

     The Auto Clean threshold is snapped to a slider stop when it is stored.

     - Parameters:
       - showCPU: Whether the CPU item is shown. Defaults to true.
       - cpuMode: How the CPU item shows its value. Defaults to `.percent`.
       - showNetwork: Whether the network item is shown. Defaults to true.
       - includeLoopback: Whether loopback (lo0) traffic is counted. Defaults to false.
       - allowedInterfaces: Interface names to count. Empty counts all active interfaces.
       - collectorOverrides: Explicit on or off choices for optional collectors. Empty by default.
       - hiddenBatteryDetails: Battery readings to hide. Empty by default.
       - hiddenMenuBarItems: Items hidden from the menu bar. Defaults to `MenuBarItem.defaultHidden`.
       - menuBarPriorities: The priority for each status bar item. Empty means the defaults.
       - autoCleanEnabled: Whether Auto Clean is on. Defaults to false.
       - autoCleanThresholdPercent: The used-RAM percentage that triggers Auto Clean. Defaults to 85.
       - menuBarItemConfigs: The appearance and behaviour of each item. Empty means the defaults.
       - menuBarOrder: The order of items in the Settings list. Defaults to every item in declaration order.
       - appearance: Light, dark or system. Defaults to `.system`.
     */
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

    /**
     Reports whether a battery reading is shown.

     - Parameter detail: The battery reading to check.
     - Returns: True unless the user has hidden it.
     */
    public func isBatteryDetailShown(_ detail: BatteryDetail) -> Bool {
        !hiddenBatteryDetails.contains(detail)
    }

    /**
     Reports whether an item is shown in the menu bar.

     - Parameter item: The menu bar item to check.
     - Returns: True unless the user has hidden it.
     */
    public func isMenuBarItemShown(_ item: MenuBarItem) -> Bool {
        !hiddenMenuBarItems.contains(item)
    }

    /**
     Reports whether an optional collector runs.

     A collector runs only when the Mac supports it AND the user has not switched it off. Unsupported collectors are
     always off, even if the user once enabled them. That covers hardware changes, such as an external display or a
     disk going away.

     - Parameters:
       - kind: The collector to check.
       - capabilities: What the Mac supports.
     - Returns: True when the collector is supported and not switched off.
     */
    public func isCollectorEnabled(_ kind: CollectorKind, capabilities: MetricCapabilities) -> Bool {
        capabilities.supports(kind) && (collectorOverrides[kind] ?? true)
    }

    /**
     Returns the optional collectors that run.

     - Parameter capabilities: What the Mac supports.
     - Returns: The collectors that are supported and not switched off.
     */
    public func enabledCollectors(capabilities: MetricCapabilities) -> Set<CollectorKind> {
        Set(CollectorKind.allCases.filter { isCollectorEnabled($0, capabilities: capabilities) })
    }
}
