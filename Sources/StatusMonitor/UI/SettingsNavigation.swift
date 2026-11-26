import StatusMonitorCore
import Foundation

/// The Settings window's current section and selected item. Held by the window controller so it survives reopening.
final class SettingsNavigation: ObservableObject {
    @Published var section: SettingsView.SettingsSection? = .menuBarItems
    @Published var selected: MetricItemID? = .cpu
    /// When on, each row shows move arrows, and the list can be reordered.
    @Published var isReordering = false
}
