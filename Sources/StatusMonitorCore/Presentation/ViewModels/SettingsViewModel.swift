import Combine
import Foundation

/// Presentation state for the settings UI. Every change is persisted immediately.
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var settings: MetricSettings

    /// Raw text of the interface field. Kept separate so typing is not reformatted under the cursor.
    @Published public var interfaceText: String {
        didSet { update { $0.allowedInterfaces = InterfaceAllowListParser.parse(interfaceText) } }
    }

    /// Whether the app opens at login, as reported by the system. Nil loginItem means the feature is not wired up.
    @Published public private(set) var opensAtLogin: Bool = false
    /// Last failure from changing the login item, shown next to the toggle. Nil when the last change worked.
    @Published public private(set) var loginItemError: String?

    private let repository: SettingsRepository
    private let loginItem: LoginItemService?

    public init(repository: SettingsRepository, loginItem: LoginItemService? = nil) {
        self.repository = repository
        self.loginItem = loginItem
        let loaded = repository.load()
        settings = loaded
        interfaceText = loaded.allowedInterfaces.sorted().joined(separator: ", ")
        opensAtLogin = loginItem?.isEnabled ?? false
    }

    /// Registers or unregisters the login item, then reads back the system's state, so the toggle never shows a guess.
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

    public func setShowCPU(_ value: Bool) { update { $0.showCPU = value } }
    public func setCPUMode(_ value: CPUDisplayMode) { update { $0.cpuMode = value } }
    public func setShowNetwork(_ value: Bool) { update { $0.showNetwork = value } }
    public func setIncludeLoopback(_ value: Bool) { update { $0.includeLoopback = value } }

    public func setAutoCleanEnabled(_ value: Bool) {
        update { $0.autoCleanEnabled = value }
    }

    /// Sets the used-RAM percentage that triggers Auto Clean. Snapped to a slider stop (70–100 in 5% steps).
    public func setAutoCleanThresholdPercent(_ percent: Int) {
        update { $0.autoCleanThresholdPercent = AutoCleanThreshold.snapped(percent) }
    }

    /// Stores the appearance and behaviour config for one status bar item.
    public func setItemConfig(_ item: MetricItemID, _ config: MenuBarItemConfig) {
        update { $0.menuBarItemConfigs[item] = config }
    }

    /// Sets light, dark or system appearance for the popover and Settings window.
    public func setAppearance(_ mode: AppearanceMode) {
        update { $0.appearance = mode }
    }

    /// Stores the order of the items in the Settings list.
    public func setMenuBarOrder(_ order: [MetricItemID]) {
        update { $0.menuBarOrder = order }
    }

    /// Sets how important a status bar item is. Priority decides the order and, later, what hides first when the bar is full.
    public func setMenuBarPriority(_ item: MetricItemID, _ priority: MenuBarPriority) {
        update { $0.menuBarPriorities[item] = priority }
    }

    /// Shows or hides an item in the menu bar. Turning an item on also turns its card on, because an item
    /// whose metric is switched off cannot be shown. Turning it off only hides it from the bar.
    public func setItemInMenuBar(_ item: MetricItemID, shown: Bool) {
        update { settings in
            switch item {
            case .cpu: settings.showCPU = shown
            case .network: settings.showNetwork = shown
            case .ram: break  // merged into CPU, so it has no switch of its own
            default:
                if shown, let kind = CollectorKind(rawValue: item.rawValue) {
                    settings.collectorOverrides[kind] = true
                }
                if let legacy = MenuBarItem(rawValue: item.rawValue) {
                    if shown { settings.hiddenMenuBarItems.remove(legacy) } else { settings.hiddenMenuBarItems.insert(legacy) }
                }
            }
        }
    }

    /// Shows or hides one item in the menu bar. The popover is not affected.
    public func setMenuBarItem(_ item: MenuBarItem, shown: Bool) {
        update { settings in
            if shown {
                settings.hiddenMenuBarItems.remove(item)
            } else {
                settings.hiddenMenuBarItems.insert(item)
            }
        }
    }

    /// Shows or hides one battery reading in the popover and the menu bar.
    public func setBatteryDetail(_ detail: BatteryDetail, shown: Bool) {
        update { settings in
            if shown {
                settings.hiddenBatteryDetails.remove(detail)
            } else {
                settings.hiddenBatteryDetails.insert(detail)
            }
        }
    }

    /// Records the user's explicit choice for an optional collector.
    public func setCollectorEnabled(_ kind: CollectorKind, _ value: Bool) {
        update { $0.collectorOverrides[kind] = value }
    }

    /// Applies a mutation, publishes the new value, and writes it to the repository.
    private func update(_ change: (inout MetricSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        settings = next
        repository.save(next)
    }
}
