import Foundation

/**
 The values one row of the menu bar item list shows.

 It is a plain value, so a row whose state changes is redrawn, and two states can be compared.
 */
public struct SettingsItemRowState: Equatable, Sendable {
    /// The menu bar item this row shows.
    public let item: MetricItemID
    /// Whether the item is shown in the menu bar.
    public let isShown: Bool
    /// Whether this Mac can provide the item. Items it cannot provide stay off and show why.
    public let isSupported: Bool
    /// The item's priority.
    public let priority: MenuBarPriority

    /**
     Reads the row's values from the settings and the Mac's capabilities.

     - Parameters:
       - item: The menu bar item the row shows.
       - settings: The current settings.
       - capabilities: What the Mac can provide.
     */
    public init(item: MetricItemID, settings: MetricSettings, capabilities: MetricCapabilities) {
        self.item = item
        isShown = settings.isMenuBarItemVisible(item, capabilities: capabilities)
        if let collector = SettingsItemPresentation.collector(for: item) {
            isSupported = capabilities.supports(collector)
        } else {
            isSupported = true
        }
        priority = settings.priority(for: item)
    }
}
