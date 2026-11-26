import Foundation

/// Glyph builders for the network and disk items, which report rates in two directions.
enum MenuBarGlyphRates {
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
