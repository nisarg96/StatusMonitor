import Foundation

/// Glyph builders for the network and disk items, which report rates in two directions.
enum MenuBarGlyphRates {
    /**
     Builds the network item from the download and upload rates.

     Only the enabled directions are drawn. With one direction, stacked falls back to a single line. Alerts look only at
     the enabled directions.

     - Parameters:
       - inputs: The renderer inputs.
     - Returns: The glyph for the current style, or nil when no direction is enabled.
     */
    static func network(_ inputs: MenuBarGlyphInputs) -> MenuBarGlyph? {
        let directions = inputs.networkDirections
        guard let primary = directions.first else { return nil }
        let down = inputs.snapshot.downBps
        let upload = inputs.snapshot.upBps
        let alert = inputs.isAlert(directions.map { $0.rate(upBps: upload, downBps: down) }.max() ?? 0)
        if directions.count == 2, inputs.style == .stacked || inputs.style == .grouped {
            return .stacked(symbol: MetricSymbol.network, top: "↑ \(Format.rate(upload))",
                            bottom: "↓ \(Format.rate(down))", alert: alert)
        }
        let value = "\(primary.arrow) \(Format.rate(primary.rate(upBps: upload, downBps: down)))"
        if inputs.style == .sparkline {
            return .sparkline(symbol: MetricSymbol.network,
                              levels: inputs.levels(primary.historySeries, percentScale: false),
                              value: value, alert: alert)
        }
        return .text(symbol: MetricSymbol.network, value: value, alert: alert)
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
