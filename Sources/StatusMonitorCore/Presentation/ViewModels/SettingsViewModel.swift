import Combine
import Foundation

/**
 Presentation state for the settings UI.

 Every change is persisted immediately.
 */
public final class SettingsViewModel: ObservableObject {
    /// The current settings. Changed only through this view model's setters, each of which saves the change.
    @Published public private(set) var settings: MetricSettings

    /// Raw text of the interface field. Kept separate so typing is not reformatted under the cursor.
    @Published public var interfaceText: String {
        didSet { update { $0.allowedInterfaces = InterfaceAllowListParser.parse(interfaceText) } }
    }

    /// Whether the app opens at login, as reported by the system. False when there is no login item service.
    @Published public private(set) var opensAtLogin: Bool = false
    /// Last failure from changing the login item, shown next to the toggle. Nil when the last change worked.
    @Published public private(set) var loginItemError: String?

    private let repository: SettingsRepository
    private let loginItem: LoginItemService?

    /**
     Creates the view model from the saved settings.

     - Parameters:
       - repository: Loads and saves the settings.
       - loginItem: Registers the app to open at login. Nil when the feature is not wired up.
     */
    public init(repository: SettingsRepository, loginItem: LoginItemService? = nil) {
        self.repository = repository
        self.loginItem = loginItem
        let loaded = repository.load()
        settings = loaded
        interfaceText = loaded.allowedInterfaces.sorted().joined(separator: ", ")
        opensAtLogin = loginItem?.isEnabled ?? false
    }

    /**
     Registers or unregisters the login item.

     The system's state is read back afterwards, so the toggle never shows a guess.

     - Parameters:
       - value: True to open the app at login.
     */
    public func setOpensAtLogin(_ value: Bool) {
        guard let loginItem else { return }
        do {
            try loginItem.setEnabled(value)
            loginItemError = nil
        } catch {
            loginItemError = "Could not change login item: \(error.localizedDescription)"
        }
        opensAtLogin = loginItem.isEnabled
    }

    /// Shows or hides the CPU section, which includes used RAM.
    public func setShowCPU(_ value: Bool) { update { $0.showCPU = value } }
    /// Sets whether the CPU item shows CPU percent or used RAM in GB.
    public func setCPUMode(_ value: CPUDisplayMode) { update { $0.cpuMode = value } }
    /// Shows or hides the network readout.
    public func setShowNetwork(_ value: Bool) { update { $0.showNetwork = value } }
    /// Shows or hides the download rate on the network item and card.
    public func setShowDownload(_ value: Bool) { update { $0.showDownload = value } }
    /// Shows or hides the upload rate on the network item and card.
    public func setShowUpload(_ value: Bool) { update { $0.showUpload = value } }
    /// Turns loopback (lo0) traffic in or out of the network totals.
    public func setIncludeLoopback(_ value: Bool) { update { $0.includeLoopback = value } }

    /// Turns Auto Clean on or off.
    public func setAutoCleanEnabled(_ value: Bool) {
        update { $0.autoCleanEnabled = value }
    }

    /**
     Sets the used-RAM percentage that triggers Auto Clean.

     The value is snapped to a slider stop (70–100 in 5% steps).

     - Parameters:
       - percent: The threshold, in percent of physical RAM.
     */
    public func setAutoCleanThresholdPercent(_ percent: Int) {
        update { $0.autoCleanThresholdPercent = AutoCleanThreshold.snapped(percent) }
    }

    /**
     Stores the appearance and behaviour config for one status bar item.

     - Parameters:
       - item: The status bar item.
       - config: The item's new config.
     */
    public func setItemConfig(_ item: MetricItemID, _ config: MenuBarItemConfig) {
        update { $0.menuBarItemConfigs[item] = config }
    }

    /// Bytes per second in one MB/s of the alert field. Uses 1024 steps.
    public static let bytesPerMegabyte: Double = 1024 * 1024

    /**
     Returns the default alert threshold for an item, in the stored unit.

     The stored unit is bytes per second for network and disk, and percent or degrees for the rest.

     - Parameters:
       - item: The status bar item.
     - Returns: 50 MB/s for network, 500 MB/s for disk, 90 °C for temperature, 80% otherwise.
     */
    public static func defaultAlert(for item: MetricItemID) -> Double {
        switch item {
        case .network: return 50 * bytesPerMegabyte
        case .disk: return 500 * bytesPerMegabyte
        case .thermal: return 90
        default: return 80
        }
    }

    /**
     Returns the alert threshold in the unit the field shows.

     MB/s for network and disk, and the raw value for the rest.

     - Parameters:
       - item: The status bar item.
     - Returns: The threshold in the field's unit.
     */
    public func alertDisplayValue(_ item: MetricItemID) -> Double {
        let stored = settings.itemConfig(for: item).alertAbove ?? Self.defaultAlert(for: item)
        return Self.usesRateUnit(item) ? stored / Self.bytesPerMegabyte : stored
    }

    /**
     Stores an alert threshold typed in the field's unit.

     Entering N for network or disk stores N * 1024 * 1024 bytes per second. Negative values are clamped to zero.

     - Parameters:
       - item: The status bar item.
       - value: The threshold, in the field's unit.
     */
    public func setAlertDisplayValue(_ item: MetricItemID, _ value: Double) {
        let clamped = max(0, value)
        var config = settings.itemConfig(for: item)
        config.alertAbove = Self.usesRateUnit(item) ? clamped * Self.bytesPerMegabyte : clamped
        setItemConfig(item, config)
    }

    private static func usesRateUnit(_ item: MetricItemID) -> Bool {
        item == .network || item == .disk
    }

    /// Sets light, dark or system appearance for the popover and Settings window.
    public func setAppearance(_ mode: AppearanceMode) {
        update { $0.appearance = mode }
    }

    /// Stores the order of the items in the Settings list.
    public func setMenuBarOrder(_ order: [MetricItemID]) {
        update { $0.menuBarOrder = order }
    }

    /**
     Sets how important a status bar item is.

     Priority is stored now. It does not move the item, and it will decide what hides first when the bar is full.

     - Parameters:
       - item: The status bar item.
       - priority: The item's new priority.
     */
    public func setMenuBarPriority(_ item: MetricItemID, _ priority: MenuBarPriority) {
        update { $0.menuBarPriorities[item] = priority }
    }

    /**
     Shows or hides an item in the menu bar.

     Turning an item on also turns its card on, because an item whose metric is switched off cannot be shown. Turning
     it off only hides it from the bar. RAM has no switch of its own, because it is merged into CPU.

     - Parameters:
       - item: The status bar item.
       - shown: True to show the item in the menu bar.
     */
    public func setItemInMenuBar(_ item: MetricItemID, shown: Bool) {
        update { settings in
            switch item {
            case .cpu: settings.showCPU = shown
            case .network: settings.showNetwork = shown
            case .ram: break
            default:
                if shown, let kind = CollectorKind(rawValue: item.rawValue) {
                    settings.collectorOverrides[kind] = true
                }
                if let legacy = MenuBarItem(rawValue: item.rawValue) {
                    if shown {
                        settings.hiddenMenuBarItems.remove(legacy)
                    } else {
                        settings.hiddenMenuBarItems.insert(legacy)
                    }
                }
            }
        }
    }

    /**
     Shows or hides one item in the menu bar.

     The popover is not affected.

     - Parameters:
       - item: The legacy menu bar item.
       - shown: True to show the item in the menu bar.
     */
    public func setMenuBarItem(_ item: MenuBarItem, shown: Bool) {
        update { settings in
            if shown {
                settings.hiddenMenuBarItems.remove(item)
            } else {
                settings.hiddenMenuBarItems.insert(item)
            }
        }
    }

    /**
     Shows or hides one battery reading in the popover and the menu bar.

     - Parameters:
       - detail: The battery reading.
       - shown: True to show the reading.
     */
    public func setBatteryDetail(_ detail: BatteryDetail, shown: Bool) {
        update { settings in
            if shown {
                settings.hiddenBatteryDetails.remove(detail)
            } else {
                settings.hiddenBatteryDetails.insert(detail)
            }
        }
    }

    /**
     Records the user's explicit choice for an optional collector.

     - Parameters:
       - kind: The collector.
       - value: True to enable the collector.
     */
    public func setCollectorEnabled(_ kind: CollectorKind, _ value: Bool) {
        update { $0.collectorOverrides[kind] = value }
    }

    /**
     Applies a mutation, publishes the new value, and writes it to the repository.

     Does nothing when the change leaves the settings unchanged.
     */
    private func update(_ change: (inout MetricSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        settings = next
        repository.save(next)
    }
}
