import Foundation

/// The Settings pages that exist now, in sidebar order.
public enum SettingsPane: String, CaseIterable, Sendable {
    case menuBarItems
    case general
    case memoryClean

    public var title: String {
        switch self {
        case .menuBarItems: return "Menu bar items"
        case .general: return "General"
        case .memoryClean: return "Memory Clean"
        }
    }
}

/// One row of the Settings sidebar. Coming-later rows are shown greyed and cannot be selected.
public enum SettingsSidebarItem: Equatable, Sendable {
    case pane(SettingsPane)
    case comingLater(String)

    /// Pages listed under "Coming later". They have no content yet.
    public static let comingLaterTitles = ["Sampling", "Alerts", "About"]

    /// The pane that is selected after a click. A coming-later click leaves the current pane selected.
    public static func resolve(current: SettingsPane, tapped: SettingsSidebarItem) -> SettingsPane {
        switch tapped {
        case .pane(let pane): return pane
        case .comingLater: return current
        }
    }
}
