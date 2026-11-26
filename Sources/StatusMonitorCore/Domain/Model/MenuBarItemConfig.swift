import Foundation

/// How one status bar item is drawn.
public enum MenuBarItemStyle: String, CaseIterable, Codable, Sendable {
    /// Icon and one value, e.g. "CPU 14%". Narrowest.
    case value
    /// Two values stacked in one slot, e.g. upload above download.
    case stacked
    /// A small bar per core, or one bar for a single metric.
    case bars
    /// The last samples as a line, plus the current value.
    case sparkline
    /// A ring that fills with the percentage.
    case ring
    /// Two related metrics on one item, with the alert colour applied when a threshold is crossed.
    case grouped
    /// Icon only, no value. Used for memory pressure, where the icon's shape carries the state.
    case icon
}

/// What a click on the item does.
public enum MenuBarClickAction: String, CaseIterable, Codable, Sendable {
    /// Shows the popover.
    case showPopover
    /// Opens Activity Monitor.
    case openActivityMonitor
    /// Does nothing.
    case nothing
}

/**
 Per-item appearance and behaviour.

 Every field has a default, so a missing config never breaks the bar. Refresh is not per item: every item uses the
 global cadence (2 s open, 5 s closed).
 */
public struct MenuBarItemConfig: Equatable, Codable, Sendable {
    /// How the item is drawn.
    public var style: MenuBarItemStyle
    /// Hide the item while its value is below `idleBelow`, for example network under 100,000 bytes per second.
    public var hideWhenIdle: Bool
    /// Bytes per second for network and disk, percent for the other metrics.
    public var idleBelow: Double
    /// Value above which the item takes the alert colour. Nil means no alert.
    public var alertAbove: Double?
    /// What a click on the item does.
    public var onClick: MenuBarClickAction

    /**
     Creates a config.

     - Parameters:
       - style: How the item is drawn. Defaults to `.value`.
       - hideWhenIdle: Whether to hide the item while its value is below `idleBelow`. Defaults to false.
       - idleBelow: The idle threshold, in bytes per second for network and disk and in percent for the other metrics.
         Defaults to 100,000.
       - alertAbove: The value above which the item takes the alert colour, or nil for no alert. Defaults to nil.
       - onClick: What a click on the item does. Defaults to `.showPopover`.
     */
    public init(
        style: MenuBarItemStyle = .value,
        hideWhenIdle: Bool = false,
        idleBelow: Double = 100_000,
        alertAbove: Double? = nil,
        onClick: MenuBarClickAction = .showPopover
    ) {
        self.style = style
        self.hideWhenIdle = hideWhenIdle
        self.idleBelow = idleBelow
        self.alertAbove = alertAbove
        self.onClick = onClick
    }

    /**
     Returns the styles that make sense for an item. The Settings picker shows only these.

     - Parameter item: The item to list styles for.
     - Returns: The styles the item may use.
     */
    public static func allowedStyles(for item: MetricItemID) -> [MenuBarItemStyle] {
        switch item {
        case .network, .disk: return [.value, .stacked, .sparkline, .grouped]
        case .cpu: return [.value, .bars, .sparkline, .ring]
        case .ram, .gpu, .thermal, .battery: return [.value, .ring, .sparkline]
        case .memoryPressure: return [.icon, .value]
        }
    }

    /**
     Returns the default config for an item.

     Defaults come from the designer's review: network and disk stacked, CPU/RAM/GPU/temperature as icon + value, and
     memory pressure as icon only. Disk hides while idle by default. Battery stays off in the bar by default.

     - Parameter item: The item to get the default config for.
     - Returns: The default config.
     */
    public static func defaults(for item: MetricItemID) -> MenuBarItemConfig {
        switch item {
        case .network: return MenuBarItemConfig(style: .stacked, hideWhenIdle: false)
        case .disk: return MenuBarItemConfig(style: .stacked, hideWhenIdle: true)
        case .cpu, .ram, .gpu, .thermal: return MenuBarItemConfig(style: .value)
        case .memoryPressure: return MenuBarItemConfig(style: .icon)
        case .battery: return MenuBarItemConfig(style: .value)
        }
    }
}

extension MetricSettings {
    /**
     Returns the config for an item.

     - Parameter item: The item to get the config for.
     - Returns: The user's config for the item, or its default when the user has not set one.
     */
    public func itemConfig(for item: MetricItemID) -> MenuBarItemConfig {
        menuBarItemConfigs[item] ?? MenuBarItemConfig.defaults(for: item)
    }
}
