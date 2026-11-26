import StatusMonitorCore
import Foundation

/// The Settings window's selected pane and menu bar item. Held by the window controller so it survives reopening.
final class SettingsNavigation: ObservableObject {
    @Published var pane: SettingsPane = .menuBarItems
    @Published var selected: MetricItemID? = .cpu

    /// Selects a sidebar row. Coming-later rows leave the current pane selected.
    func select(_ item: SettingsSidebarItem) {
        pane = SettingsSidebarItem.resolve(current: pane, tapped: item)
    }
}
