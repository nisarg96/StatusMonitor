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
    case showPopover
    case openActivityMonitor
    case nothing
}

/// Per-item appearance and behaviour. Every field has a default, so a missing config never breaks the bar.
/// Refresh is not per item: every item uses the global cadence (2 s open, 5 s closed).
public struct MenuBarItemConfig: Equatable, Codable, Sendable {
    public var style: MenuBarItemStyle
    /// Hide the item while its value is below `idleBelow`, for example network under 100 KB/s.
    public var hideWhenIdle: Bool
    /// Bytes per second for network and disk, percent for the other metrics.
    public var idleBelow: Double
    /// Value above which the item takes the alert colour. Nil means no alert.
    public var alertAbove: Double?
    public var onClick: MenuBarClickAction

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

    /// Styles that make sense for each item. The Settings picker shows only these.
    public static func allowedStyles(for item: MetricItemID) -> [MenuBarItemStyle] {
        switch item {
        case .network, .disk: return [.value, .stacked, .sparkline, .grouped]
        case .cpu: return [.value, .bars, .sparkline, .ring]
        case .ram, .gpu, .thermal, .battery: return [.value, .ring, .sparkline]
        case .memoryPressure: return [.icon, .value]
        }
    }

    /// Defaults from the designer's review: network and disk stacked, CPU/RAM/GPU/temperature as icon + value,
    /// memory pressure icon only. Disk hides while idle by default. Battery stays off in the bar by default.
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
    /// The config for an item, or its default if the user has not set one.
    public func itemConfig(for item: MetricItemID) -> MenuBarItemConfig {
        menuBarItemConfigs[item] ?? MenuBarItemConfig.defaults(for: item)
    }
}
