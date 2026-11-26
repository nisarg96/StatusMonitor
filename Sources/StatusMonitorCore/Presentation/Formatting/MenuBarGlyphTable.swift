import Foundation

/// Which renderer draws an item. Most items have one slot each; CPU has a second slot while it shows RAM in GB.
enum MenuBarGlyphSlot: Hashable {
    /// The renderer for one metric item.
    case item(MetricItemID)
    /// The CPU renderer used while the CPU item shows used RAM in GB.
    case cpuMemoryMode
}

/// Builds one item's glyph from the inputs, or nil when the item has no value.
typealias MenuBarGlyphRenderer = @Sendable (MenuBarGlyphInputs) -> MenuBarGlyph?

/// Maps each slot to the function that builds its glyph. Each function switches on the item's style.
enum MenuBarGlyphTable {
    /// The renderer for each slot.
    static let renderers: [MenuBarGlyphSlot: MenuBarGlyphRenderer] = [
        .item(.cpu): MenuBarGlyphItems.cpu,
        .cpuMemoryMode: MenuBarGlyphItems.cpuMemory,
        .item(.ram): MenuBarGlyphItems.ram,
        .item(.gpu): MenuBarGlyphItems.gpu,
        .item(.network): MenuBarGlyphRates.network,
        .item(.disk): MenuBarGlyphRates.disk,
        .item(.memoryPressure): MenuBarGlyphItems.memoryPressure,
        .item(.thermal): MenuBarGlyphItems.thermal,
        .item(.battery): MenuBarGlyphItems.battery
    ]

    /**
     Returns the slot that renders an item in the given CPU mode.

     - Parameters:
       - item: The status bar item.
       - cpuMode: How the CPU item is shown.
     - Returns: `.cpuMemoryMode` for the CPU item in RAM mode, otherwise `.item(item)`.
     */
    static func slot(for item: MetricItemID, cpuMode: CPUDisplayMode) -> MenuBarGlyphSlot {
        item == .cpu && cpuMode == .memoryGB ? .cpuMemoryMode : .item(item)
    }
}
