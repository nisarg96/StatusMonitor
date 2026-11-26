import StatusMonitorCore
import Foundation

/**
 The Settings window's selected pane and menu bar item.

 The window controller holds it, so the selection survives reopening the window.
 */
final class SettingsNavigation: ObservableObject {
    /// The selected pane.
    @Published var pane: SettingsPane = .menuBarItems
    /// The selected menu bar item in the Menu bar items pane.
    @Published var selected: MetricItemID? = .cpu

    /**
     Selects a sidebar row. Coming-later rows leave the current pane selected.

     - Parameter item: The sidebar row that was tapped.
     */
    func select(_ item: SettingsSidebarItem) {
        pane = SettingsSidebarItem.resolve(current: pane, tapped: item)
    }
}
