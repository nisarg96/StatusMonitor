import StatusMonitorCore
import SwiftUI

/// Two-way bindings from the Settings controls to the settings view model. Views hold no state of their own.
struct SettingsItemBindings {
    let settings: SettingsViewModel
    let monitor: MonitorViewModel

    /// Whether this Mac can provide the item. Items it cannot provide stay off and show why.
    func isSupported(_ item: MetricItemID) -> Bool {
        guard let collector = SettingsItemPresentation.collector(for: item) else { return true }
        return monitor.capabilities.supports(collector)
    }

    func shown(_ item: MetricItemID) -> Binding<Bool> {
        Binding(
            get: { settings.settings.isMenuBarItemVisible(item, capabilities: monitor.capabilities) },
            set: { settings.setItemInMenuBar(item, shown: $0) }
        )
    }

    func priority(_ item: MetricItemID) -> Binding<MenuBarPriority> {
        Binding(
            get: { settings.settings.priority(for: item) },
            set: { settings.setMenuBarPriority(item, $0) }
        )
    }

    func style(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<MenuBarItemStyle> {
        Binding(
            get: { config.style },
            set: { style in
                var next = config
                next.style = style
                settings.setItemConfig(item, next)
            }
        )
    }

    func onClick(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<MenuBarClickAction> {
        Binding(
            get: { config.onClick },
            set: { action in
                var next = config
                next.onClick = action
                settings.setItemConfig(item, next)
            }
        )
    }

    func hideWhenIdle(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Bool> {
        Binding(
            get: { config.hideWhenIdle },
            set: { value in
                var next = config
                next.hideWhenIdle = value
                settings.setItemConfig(item, next)
            }
        )
    }

    /// The idle threshold is typed in KB/s and stored in bytes per second.
    func idleKB(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Double> {
        Binding(
            get: { SettingsItemPresentation.idleKB(fromBytes: config.idleBelow) },
            set: { value in
                var next = config
                next.idleBelow = SettingsItemPresentation.idleBytes(fromKB: value)
                settings.setItemConfig(item, next)
            }
        )
    }

    /// Whether the warning threshold is on. Turning it on uses the item's default threshold.
    func warningOn(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Bool> {
        Binding(
            get: { config.alertAbove != nil },
            set: { isOn in
                var next = config
                next.alertAbove = isOn ? SettingsViewModel.defaultAlert(for: item) : nil
                settings.setItemConfig(item, next)
            }
        )
    }

    /// The warning threshold in the unit the field shows (MB/s for rates).
    func warningValue(_ item: MetricItemID) -> Binding<Double> {
        Binding(
            get: { settings.alertDisplayValue(item) },
            set: { settings.setAlertDisplayValue(item, $0) }
        )
    }

    func collectorOn(_ collector: CollectorKind) -> Binding<Bool> {
        Binding(
            get: { settings.settings.collectorOverrides[collector] ?? true },
            set: { settings.setCollectorEnabled(collector, $0) }
        )
    }

    func cpuMode() -> Binding<CPUDisplayMode> {
        Binding(
            get: { settings.settings.cpuMode },
            set: { settings.setCPUMode($0) }
        )
    }
}
