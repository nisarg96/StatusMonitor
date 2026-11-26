import Foundation

/// Glyph builders for the network and disk items, which report rates in two directions.
enum MenuBarGlyphRates {
    /**
     Builds the network item from the download and upload rates.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style.
     */
    static func network(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        let down = inputs.snapshot.downBps
        let upload = inputs.snapshot.upBps
        let alert = inputs.isAlert(max(down, upload))
        switch inputs.style {
        case .stacked, .grouped:
            return .stacked(symbol: MetricSymbol.network, top: "↑ \(Format.rate(upload))",
                            bottom: "↓ \(Format.rate(down))", alert: alert)
        case .sparkline:
            return .sparkline(symbol: MetricSymbol.network, levels: inputs.levels(.networkDown, percentScale: false),
                              value: "↓ \(Format.rate(down))", alert: alert)
        default:
            return .text(symbol: MetricSymbol.network, value: "↓ \(Format.rate(down))", alert: alert)
        }
    }

    /**
     Builds the disk item from the read and write rates.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil when there is no disk reading.
     */
    static func disk(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        guard let disk = inputs.snapshot.disk else { return nil }
        let alert = inputs.isAlert(max(disk.readBps, disk.writeBps))
        switch inputs.style {
        case .stacked, .grouped:
            return .stacked(symbol: MetricSymbol.disk, top: "↑ \(Format.rate(disk.writeBps))",
                            bottom: "↓ \(Format.rate(disk.readBps))", alert: alert)
        case .sparkline:
            return .sparkline(symbol: MetricSymbol.disk, levels: inputs.levels(.diskRead, percentScale: false),
                              value: "↓ \(Format.rate(disk.readBps))", alert: alert)
        default:
            return .text(symbol: MetricSymbol.disk, value: "↓ \(Format.rate(disk.readBps))", alert: alert)
        }
    }
}
