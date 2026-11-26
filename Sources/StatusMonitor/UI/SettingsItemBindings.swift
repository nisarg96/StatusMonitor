import StatusMonitorCore
import SwiftUI

/// Two-way bindings from the Settings controls to the settings view model. Views hold no state of their own.
struct SettingsItemBindings {
    /// The settings view model that the bindings write to.
    let settings: SettingsViewModel
    /// The monitor, which supplies the capabilities that decide what the Mac can show.
    let monitor: MonitorViewModel

    /**
     Returns a binding to whether an item is shown in the menu bar.

     The getter returns `current`, which the parent passes from the settings, so the control redraws when the settings
     change. The setter writes through the settings view model.

     - Parameters:
       - item: The menu bar item.
       - current: Whether the item is shown now.
     - Returns: The binding.
     */
    func shown(_ item: MetricItemID, current: Bool) -> Binding<Bool> {
        Binding(
            get: { current },
            set: { settings.setItemInMenuBar(item, shown: $0) }
        )
    }

    /**
     Returns a binding to an item's menu bar priority.

     The getter returns `current`, which the parent passes from the settings. The setter writes through the settings
     view model.

     - Parameters:
       - item: The menu bar item.
       - current: The item's priority now.
     - Returns: The binding.
     */
    func priority(_ item: MetricItemID, current: MenuBarPriority) -> Binding<MenuBarPriority> {
        Binding(
            get: { current },
            set: { settings.setMenuBarPriority(item, $0) }
        )
    }

    /**
     Returns a binding to an item's style.

     - Parameter item: The menu bar item.
     - Parameter config: The item's current configuration, which the change is applied to.
     - Returns: The binding.
     */
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

    /**
     Returns a binding to an item's click action.

     - Parameter item: The menu bar item.
     - Parameter config: The item's current configuration, which the change is applied to.
     - Returns: The binding.
     */
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

    /**
     Returns a binding to whether an item is hidden while idle.

     - Parameter item: The menu bar item.
     - Parameter config: The item's current configuration, which the change is applied to.
     - Returns: The binding.
     */
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

    /**
     Returns a binding to the idle threshold, shown and typed in KB/s.

     The value is stored in bytes per second.

     - Parameter item: The menu bar item.
     - Parameter config: The item's current configuration, which the change is applied to.
     - Returns: The binding, in KB/s.
     */
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

    /**
     Returns a binding to whether the warning threshold is on.

     Turning it on uses the item's default threshold.

     - Parameter item: The menu bar item.
     - Parameter config: The item's current configuration, which the change is applied to.
     - Returns: The binding.
     */
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

    /**
     Returns a binding to the warning threshold in the unit the field shows.

     Rates are shown in MB/s.

     - Parameter item: The menu bar item.
     - Returns: The binding, in the field's unit.
     */
    func warningValue(_ item: MetricItemID) -> Binding<Double> {
        Binding(
            get: { settings.alertDisplayValue(item) },
            set: { settings.setAlertDisplayValue(item, $0) }
        )
    }

    /**
     Returns a binding to whether a collector is enabled. Collectors are enabled unless turned off.

     - Parameter collector: The collector to bind.
     - Returns: The binding.
     */
    func collectorOn(_ collector: CollectorKind) -> Binding<Bool> {
        Binding(
            get: { settings.settings.collectorOverrides[collector] ?? true },
            set: { settings.setCollectorEnabled(collector, $0) }
        )
    }

    /**
     Returns a binding to whether one network direction is shown on the Network item and card.

     - Parameter direction: The direction, download or upload.
     - Returns: The binding.
     */
    func networkDirection(_ direction: NetworkDirection) -> Binding<Bool> {
        Binding(
            get: { direction == .download ? settings.settings.showDownload : settings.settings.showUpload },
            set: { value in
                switch direction {
                case .download: settings.setShowDownload(value)
                case .upload: settings.setShowUpload(value)
                }
            }
        )
    }

    /**
     Returns a binding to the CPU display mode, which picks between CPU percent and used RAM.

     - Returns: The binding.
     */
    func cpuMode() -> Binding<CPUDisplayMode> {
        Binding(
            get: { settings.settings.cpuMode },
            set: { settings.setCPUMode($0) }
        )
    }
}
