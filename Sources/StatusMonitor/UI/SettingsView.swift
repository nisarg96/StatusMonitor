import StatusMonitorCore
import SwiftUI

/// The Settings window: a sidebar of panes and the selected pane. The popover only shows values and opens this window.
struct SettingsView: View {
    /// The settings view model that the panes edit.
    @ObservedObject var settings: SettingsViewModel
    /// The monitor, which supplies the live readings and the capabilities.
    @ObservedObject var monitor: MonitorViewModel
    /// The purge approval state shown on the Memory Clean pane.
    @ObservedObject var purge: PurgePermissionViewModel
    /// The selected pane and menu bar item.
    @ObservedObject var navigation: SettingsNavigation
    /// Nil until the app wires the clean use case in. Without it the Clean now controls are hidden.
    let memoryClean: MemoryCleanViewModel?

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: navigation.pane) { navigation.select($0) }
                .frame(width: 188)
            Divider()
            pane
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(settings.settings.appearance.colorScheme)
        .tint(SettingsPalette.accent)
    }

    @ViewBuilder
    private var pane: some View {
        switch navigation.pane {
        case .menuBarItems:
            SettingsMenuBarItemsPane(settings: settings, monitor: monitor, navigation: navigation)
        case .general:
            SettingsGeneralPane(settings: settings)
        case .memoryClean:
            MemoryCleanSettingsPane(settings: settings, purge: purge, memoryClean: memoryClean)
        }
    }
}
