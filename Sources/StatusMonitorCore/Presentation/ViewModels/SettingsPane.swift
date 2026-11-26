import Foundation

/// The Settings pages that exist now, in sidebar order.
public enum SettingsPane: String, CaseIterable, Sendable {
    /// The menu bar item list and its detail pane.
    case menuBarItems
    /// General settings.
    case general
    /// Memory Clean settings and the Auto Clean threshold.
    case memoryClean

    /// The sidebar title for the page.
    public var title: String {
        switch self {
        case .menuBarItems: return "Menu bar items"
        case .general: return "General"
        case .memoryClean: return "Memory Clean"
        }
    }
}

/**
 One row of the Settings sidebar.

 Coming-later rows are shown greyed and cannot be selected.
 */
public enum SettingsSidebarItem: Equatable, Sendable {
    /// A page that exists.
    case pane(SettingsPane)
    /// A placeholder row for a page not yet built, with its title.
    case comingLater(String)

    /// Pages listed under "Coming later". They have no content yet.
    public static let comingLaterTitles = ["Sampling", "Alerts", "About"]

    /**
     Returns the pane to select after a sidebar row is tapped.

     A coming-later click leaves the current pane selected.

     - Parameters:
       - current: The pane selected now.
       - tapped: The row that was tapped.
     - Returns: The pane to show.
     */
    public static func resolve(current: SettingsPane, tapped: SettingsSidebarItem) -> SettingsPane {
        switch tapped {
        case .pane(let pane): return pane
        case .comingLater: return current
        }
    }
}
