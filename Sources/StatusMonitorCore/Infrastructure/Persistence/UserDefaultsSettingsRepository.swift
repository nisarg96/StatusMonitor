import Foundation

/**
 Persists `MetricSettings` in UserDefaults under stable keys.

 Inject a suite-named `UserDefaults` in tests to keep them isolated from the real preferences.
 */
public final class UserDefaultsSettingsRepository: SettingsRepository {
    /// Stable UserDefaults keys. Renaming one loses the value the user already saved.
    enum Key {
        static let showCPU = "showCPU"
        static let cpuMode = "cpuMode"
        static let showNetwork = "showNetwork"
        static let showDownload = "showDownload"
        static let showUpload = "showUpload"
        static let includeLoopback = "includeLoopback"
        static let allowedInterfaces = "allowedInterfaces"
        static let collectorOverrides = "collectorOverrides"
        static let hiddenBatteryDetails = "hiddenBatteryDetails"
        static let hiddenMenuBarItems = "hiddenMenuBarItems"
        static let menuBarPriorities = "menuBarPriorities"
        static let autoCleanEnabled = "autoCleanEnabled"
        static let autoCleanThresholdPercent = "autoCleanThresholdPercent"
        static let menuBarItemConfigs = "menuBarItemConfigs"
        static let menuBarOrder = "menuBarOrder"
        static let appearance = "appearance"
    }

    private let defaults: UserDefaults

    /**
     Creates a repository backed by a UserDefaults domain.

     - Parameters:
       - defaults: The defaults database to read and write.
     */
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /**
     Reads the settings, applying defaults for every key that has no usable stored value.

     Unknown collector, battery-detail, menu-bar and priority names are dropped, so old or newer preference files
     still load. Without a stored hidden-items list, the crowded-bar defaults apply; a stored empty list means
     show everything.

     - Returns: The stored settings merged with the defaults.
     */
    public func load() -> MetricSettings {
        var overrides: [CollectorKind: Bool] = [:]
        for (name, value) in defaults.dictionary(forKey: Key.collectorOverrides) as? [String: Bool] ?? [:] {
            if let kind = CollectorKind(rawValue: name) {
                overrides[kind] = value
            }
        }

        let hidden = (defaults.stringArray(forKey: Key.hiddenBatteryDetails) ?? [])
            .compactMap { BatteryDetail(rawValue: $0) }

        let hiddenItems: Set<MenuBarItem>
        if let stored = defaults.stringArray(forKey: Key.hiddenMenuBarItems) {
            hiddenItems = Set(stored.compactMap { MenuBarItem(rawValue: $0) })
        } else {
            hiddenItems = MenuBarItem.defaultHidden
        }

        return MetricSettings(
            showCPU: defaults.object(forKey: Key.showCPU) as? Bool ?? true,
            cpuMode: CPUDisplayMode(rawValue: defaults.string(forKey: Key.cpuMode) ?? "") ?? .percent,
            showNetwork: defaults.object(forKey: Key.showNetwork) as? Bool ?? true,
            showDownload: defaults.object(forKey: Key.showDownload) as? Bool ?? true,
            showUpload: defaults.object(forKey: Key.showUpload) as? Bool ?? true,
            includeLoopback: defaults.bool(forKey: Key.includeLoopback),
            allowedInterfaces: Set(defaults.stringArray(forKey: Key.allowedInterfaces) ?? []),
            collectorOverrides: overrides,
            hiddenBatteryDetails: Set(hidden),
            hiddenMenuBarItems: hiddenItems,
            menuBarPriorities: loadPriorities(),
            autoCleanEnabled: defaults.bool(forKey: Key.autoCleanEnabled),
            autoCleanThresholdPercent: defaults.object(forKey: Key.autoCleanThresholdPercent) as? Int
                ?? AutoCleanThreshold.defaultPercent,
            menuBarItemConfigs: loadItemConfigs(),
            menuBarOrder: loadOrder(),
            appearance: AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        )
    }

    /**
     Writes every field of the settings to UserDefaults.

     - Parameters:
       - settings: The settings to store.
     */
    public func save(_ settings: MetricSettings) {
        defaults.set(settings.showCPU, forKey: Key.showCPU)
        defaults.set(settings.cpuMode.rawValue, forKey: Key.cpuMode)
        defaults.set(settings.showNetwork, forKey: Key.showNetwork)
        defaults.set(settings.showDownload, forKey: Key.showDownload)
        defaults.set(settings.showUpload, forKey: Key.showUpload)
        defaults.set(settings.includeLoopback, forKey: Key.includeLoopback)
        defaults.set(settings.allowedInterfaces.sorted(), forKey: Key.allowedInterfaces)

        var overrides: [String: Bool] = [:]
        for (kind, value) in settings.collectorOverrides {
            overrides[kind.rawValue] = value
        }
        defaults.set(overrides, forKey: Key.collectorOverrides)

        defaults.set(settings.hiddenBatteryDetails.map(\.rawValue).sorted(), forKey: Key.hiddenBatteryDetails)
        defaults.set(settings.hiddenMenuBarItems.map(\.rawValue).sorted(), forKey: Key.hiddenMenuBarItems)

        var priorities: [String: String] = [:]
        for (item, priority) in settings.menuBarPriorities {
            priorities[item.rawValue] = priority.rawValue
        }
        defaults.set(priorities, forKey: Key.menuBarPriorities)

        defaults.set(settings.autoCleanEnabled, forKey: Key.autoCleanEnabled)
        defaults.set(settings.autoCleanThresholdPercent, forKey: Key.autoCleanThresholdPercent)

        var configs: [String: Data] = [:]
        for (item, config) in settings.menuBarItemConfigs {
            if let data = try? JSONEncoder().encode(config) {
                configs[item.rawValue] = data
            }
        }
        defaults.set(configs, forKey: Key.menuBarItemConfigs)

        defaults.set(settings.menuBarOrder.map(\.rawValue), forKey: Key.menuBarOrder)
        defaults.set(settings.appearance.rawValue, forKey: Key.appearance)
    }

    /// Stored order, completed with any item missing from it, so a new metric still gets a place.
    private func loadOrder() -> [MetricItemID] {
        let stored = (defaults.stringArray(forKey: Key.menuBarOrder) ?? []).compactMap { MetricItemID(rawValue: $0) }
        var order: [MetricItemID] = []
        for item in stored + MetricItemID.allCases where !order.contains(item) {
            order.append(item)
        }
        return order
    }

    /// Entries that fail to decode are dropped, so one bad value falls back to that item's default.
    private func loadItemConfigs() -> [MetricItemID: MenuBarItemConfig] {
        var result: [MetricItemID: MenuBarItemConfig] = [:]
        let stored = defaults.dictionary(forKey: Key.menuBarItemConfigs) as? [String: Data] ?? [:]
        for (name, data) in stored {
            if let item = MetricItemID(rawValue: name),
               let config = try? JSONDecoder().decode(MenuBarItemConfig.self, from: data) {
                result[item] = config
            }
        }
        return result
    }

    /// Unknown item or priority names are dropped, so an old or newer preference file never breaks loading.
    private func loadPriorities() -> [MetricItemID: MenuBarPriority] {
        var result: [MetricItemID: MenuBarPriority] = [:]
        let stored = defaults.dictionary(forKey: Key.menuBarPriorities) as? [String: String] ?? [:]
        for (name, value) in stored {
            if let item = MetricItemID(rawValue: name), let priority = MenuBarPriority(rawValue: value) {
                result[item] = priority
            }
        }
        return result
    }
}
