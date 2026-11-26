import AppKit
import StatusMonitorCore

/// Draws one status bar item's glyph into an image. Drawing only; the decisions come from MenuBarGlyph.
///
/// Monochrome glyphs are template images, so they follow the menu bar's light or dark appearance.
/// Alert glyphs add a shape (a triangle, or a filled item with "!") as well as colour, so they still read in greyscale.
enum MenuBarImageRenderer {
    /// Canvas height. 20 pt leaves room for two stacked lines without clipping the top one.
    static let height: CGFloat = 20
    private static let textFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private static let boldFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    /// Stacked values use a smaller size so two lines fit inside the menu bar's 22 pt height.
    private static let smallFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)

    static func image(for glyph: MenuBarGlyph) -> NSImage {
        switch glyph {
        case let .text(symbol, value, alert):
            return compose(symbol: symbol, alert: alert) { origin in
                drawText(value, at: origin, font: alert ? boldFont : textFont, color: alertColor(alert))
            }

        case let .level(symbol, value, accent):
            // Orange within 10 points below the RAM threshold, red at it. The icon takes the same colour.
            // Warning adds a triangle and bold digits. Critical adds a "!", so the state reads without colour.
            let colour = accentNSColor(accent)
            let suffix = accent == .critical ? " !" : ""
            return compose(symbol: symbol, alert: accent != .normal, iconColor: colour) { origin in
                var textOrigin = origin
                if accent == .warning, let triangle = symbolImage("exclamationmark.triangle.fill") {
                    tint(triangle, colour).draw(in: CGRect(x: origin.x, y: origin.y + 1, width: 9, height: 9))
                    textOrigin.x += 11
                }
                drawText(value + suffix, at: textOrigin, font: accent == .normal ? textFont : boldFont, color: colour)
            }

        case let .stacked(symbol, top, bottom, alert):
            // Size the slot to the wider line, so long rates like "↑ 1.2 MB/s" are not clipped.
            let width = max(textWidth(top, font: smallFont), textWidth(bottom, font: smallFont)) + 2
            return compose(symbol: symbol, alert: alert, contentWidth: width) { origin in
                // Two lines inside the 20 pt canvas: the top line sits in the upper half, the bottom line in the lower half.
                drawText(top, at: CGPoint(x: origin.x, y: 10), font: smallFont, color: alertColor(alert))
                drawText(bottom, at: CGPoint(x: origin.x, y: 0), font: smallFont, color: alertColor(alert))
            }

        case let .bars(symbol, levels, alert):
            return compose(symbol: symbol, alert: alert) { origin in
                let barWidth: CGFloat = 2
                for (index, level) in levels.suffix(12).enumerated() {
                    let barHeight = max(1, CGFloat(level) * 14)
                    let rect = CGRect(x: origin.x + CGFloat(index) * 3, y: origin.y, width: barWidth, height: barHeight)
                    alertColor(alert).setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 0.5, yRadius: 0.5).fill()
                }
            }

        case let .sparkline(symbol, levels, value, alert):
            return compose(symbol: symbol, alert: alert, trailing: value) { origin in
                guard levels.count > 1 else { return }
                let path = NSBezierPath()
                let width: CGFloat = 26
                for (index, level) in levels.enumerated() {
                    let x = origin.x + width * CGFloat(index) / CGFloat(levels.count - 1)
                    let y = origin.y + CGFloat(level) * 14
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.line(to: CGPoint(x: x, y: y)) }
                }
                alertColor(alert).setStroke()
                path.lineWidth = 1.2
                path.stroke()
            }

        case let .ring(symbol, fraction, value, alert):
            return compose(symbol: symbol, alert: alert, trailing: value) { origin in
                let centre = CGPoint(x: origin.x + 7, y: origin.y + 7)
                let track = NSBezierPath(ovalIn: CGRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12))
                NSColor.labelColor.withAlphaComponent(0.25).setStroke()
                track.lineWidth = 2
                track.stroke()

                let arc = NSBezierPath()
                arc.appendArc(withCenter: centre, radius: 6,
                              startAngle: 90, endAngle: 90 - CGFloat(max(0, min(1, fraction))) * 360,
                              clockwise: true)
                alertColor(alert).setStroke()
                arc.lineWidth = 2
                arc.lineCapStyle = .round
                arc.stroke()
            }

        case let .pressure(symbol, level):
            return pressureImage(symbol: symbol, level: level)
        }
    }

    /// The icon used for an item with no value yet, so it keeps its usual width.
    static func iconOnly(symbol: String) -> NSImage {
        let image = symbolImage(symbol) ?? NSImage(size: CGSize(width: 14, height: height))
        image.isTemplate = true
        return image
    }

    // MARK: - Composition

    /// Lays out: icon, then the drawn content, optionally followed by trailing text. The closure receives the content origin.
    private static func compose(
        symbol: String,
        alert: Bool,
        trailing: String? = nil,
        contentWidth: CGFloat = 40,
        iconColor: NSColor? = nil,
        content: @escaping (CGPoint) -> Void
    ) -> NSImage {
        let iconWidth: CGFloat = 16
        let trailingWidth: CGFloat = trailing.map { textWidth($0, font: textFont) + 4 } ?? 0
        let size = CGSize(width: iconWidth + 4 + contentWidth + trailingWidth, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            if let icon = symbolImage(symbol) {
                let rect = CGRect(x: 0, y: (height - icon.size.height) / 2, width: iconWidth, height: icon.size.height)
                tint(icon, iconColor ?? (alert ? NSColor.systemOrange : NSColor.labelColor)).draw(in: rect)
            }
            content(CGPoint(x: iconWidth + 4, y: 3))
            if let trailing {
                drawText(trailing, at: CGPoint(x: iconWidth + 4 + contentWidth + 4, y: 3),
                         font: textFont, color: alertColor(alert))
            }
            return true
        }
        image.isTemplate = !alert
        return image
    }

    /// Memory pressure: icon only. Warning adds a triangle beside it and bold weight. Critical fills the item red with "!".
    private static func pressureImage(symbol: String, level: MemoryPressureLevel) -> NSImage {
        let size = CGSize(width: 22, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            switch level {
            case .normal:
                if let icon = symbolImage(symbol) {
                    tint(icon, NSColor.labelColor).draw(in: CGRect(x: 2, y: 2, width: 14, height: 14))
                }
            case .warning:
                if let icon = symbolImage(symbol) {
                    tint(icon, NSColor.systemOrange).draw(in: CGRect(x: 2, y: 2, width: 14, height: 14))
                }
                if let triangle = symbolImage("exclamationmark.triangle.fill") {
                    tint(triangle, NSColor.systemOrange).draw(in: CGRect(x: 15, y: 3, width: 7, height: 7))
                }
            case .critical:
                let pill = NSBezierPath(roundedRect: CGRect(x: 0, y: 1, width: size.width, height: height - 2),
                                        xRadius: 4, yRadius: 4)
                NSColor.systemRed.setFill()
                pill.fill()
                if let icon = symbolImage(symbol) {
                    tint(icon, NSColor.white).draw(in: CGRect(x: 3, y: 2, width: 13, height: 14))
                }
                drawText("!", at: CGPoint(x: 16, y: 2), font: boldFont, color: .white)
            }
            return true
        }
        // Normal stays a template so it matches the bar. Warning and critical carry their own colour.
        image.isTemplate = level == .normal
        return image
    }

    // MARK: - Helpers

    /// Orange for warning, red for critical, the default label colour for normal.
    private static func accentNSColor(_ accent: ReadoutAccent) -> NSColor {
        switch accent {
        case .normal: return .labelColor
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    private static func alertColor(_ alert: Bool) -> NSColor {
        alert ? .systemOrange : .labelColor
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    private static func tint(_ image: NSImage, _ color: NSColor) -> NSImage {
        let tinted = image.copy() as? NSImage ?? image
        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }

    private static func drawText(_ text: String, at origin: CGPoint, font: NSFont, color: NSColor) {
        (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
