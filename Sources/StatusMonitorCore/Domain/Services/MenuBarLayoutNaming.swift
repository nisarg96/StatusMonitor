import Foundation

/// Autosave names for the menu bar items. Generation 0 keeps the original names, so existing positions still apply.
/// Each "Apply order" bumps the generation, so macOS places the items fresh in the order the app creates them.
public enum MenuBarLayoutNaming {
    public static func autosaveName(for item: MetricItemID, generation: Int) -> String {
        generation == 0
            ? "StatusMonitor.item.\(item.rawValue)"
            : "StatusMonitor.g\(generation).item.\(item.rawValue)"
    }

    /// Preference keys macOS keeps for a generation's items. Used to clear a retired generation.
    public static func storedKeys(forGeneration generation: Int) -> [String] {
        MetricItemID.allCases.flatMap { item -> [String] in
            let name = autosaveName(for: item, generation: generation)
            return ["NSStatusItem Preferred Position \(name)", "NSStatusItem VisibleCC \(name)"]
        }
    }
}
