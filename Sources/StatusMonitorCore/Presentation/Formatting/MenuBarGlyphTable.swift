import Foundation

/// Which renderer draws an item. Most items have one slot each; CPU has a second slot while it shows RAM in GB.
enum MenuBarGlyphSlot: Hashable {
    case item(MetricItemID)
    case cpuMemoryMode
}

typealias MenuBarGlyphRenderer = @Sendable (MenuBarGlyphInputs) -> MenuBarGlyph?

/// Maps each slot to the function that builds its glyph. Each function switches on the item's style.
enum MenuBarGlyphTable {
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

    static func slot(for item: MetricItemID, cpuMode: CPUDisplayMode) -> MenuBarGlyphSlot {
        item == .cpu && cpuMode == .memoryGB ? .cpuMemoryMode : .item(item)
    }
}
