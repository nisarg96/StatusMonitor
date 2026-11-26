import AppKit
import StatusMonitorCore

/**
 Draws one status bar item's glyph into an image. It only draws; the decisions come from `MenuBarGlyph`.

 Normal glyphs are template images, so they follow the menu bar's light or dark appearance. Warning and critical
 glyphs carry their own colours and add a shape as well (a triangle, or a filled item with "!"), so they still read
 in greyscale.
 */
enum MenuBarImageRenderer {
    /// Canvas height. 20 pt leaves room for two stacked lines without clipping the top one.
    static let height: CGFloat = 20
    private static let iconWidth: CGFloat = 16
    private static let gap: CGFloat = 4
    /// Room for the warning triangle (9 pt) and the gap after it.
    private static let markerWidth: CGFloat = 11
    private static let textFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    /// Stacked values use a smaller size so two lines fit inside the menu bar's 22 pt height.
    private static let smallFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)
    private static let smallBoldFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)

    /**
     Light and dark values for the alert states.

     Warning's pair is from the design spec. Critical's light fill is from the spec; its dark fill is derived, because
     the spec gives none (see the report).
     */
    private static let warningColour = dynamicColour(light: 0xB4_530F, dark: 0xFF_9F5A)
    private static let criticalFill = dynamicColour(light: 0xC6_2828, dark: 0xE5_3935)

    /**
     Draws a glyph into an image for the status bar or a preview.

     Critical levels add a leading "!", so the state reads without colour.

     - Parameter glyph: The glyph to draw, decided by `MenuBarGlyph`.
     - Returns: The image. Normal glyphs are templates.
     */
    static func image(for glyph: MenuBarGlyph) -> NSImage {
        switch glyph {
        case let .text(symbol, value, alert):
            return valueImage(symbol: symbol, text: value, accent: alert ? .warning : .normal)

        case let .label(title, value, alert):
            return valueImage(symbol: nil, text: "\(title) \(value)", accent: alert ? .warning : .normal)

        case let .level(symbol, value, accent):
            let text = accent == .critical ? "! \(value)" : value
            return valueImage(symbol: symbol, text: text, accent: accent)

        case let .stacked(symbol, top, bottom, alert):
            return stackedImage(symbol: symbol, top: top, bottom: bottom, accent: alert ? .warning : .normal)

        case let .bars(symbol, levels, alert):
            return compose(symbol: symbol, accent: alert ? .warning : .normal) { origin, ink in
                drawBars(levels, origin: origin, ink: ink)
            }

        case let .sparkline(symbol, levels, value, alert):
            return compose(symbol: symbol, accent: alert ? .warning : .normal, trailing: value) { origin, ink in
                drawSparkline(levels, origin: origin, ink: ink)
            }

        case let .ring(symbol, fraction, value, alert):
            return compose(symbol: symbol, accent: alert ? .warning : .normal, trailing: value) { origin, ink in
                drawRing(fraction, origin: origin, ink: ink)
            }

        case let .pressure(_, level):
            return pressureImage(level: level)
        }
    }

    /**
     Returns the icon for an item with no value yet, so the item keeps its usual width.

     - Parameter symbol: The SF Symbol name to draw.
     - Returns: A template image of the symbol, or an empty image of the usual size when the symbol is missing.
     */
    static func iconOnly(symbol: String) -> NSImage {
        let image = symbolImage(symbol) ?? NSImage(size: CGSize(width: 14, height: height))
        image.isTemplate = true
        return image
    }

    // MARK: - Glyph kinds

    /**
     Draws a value as text, with an optional icon.

     Warning uses bold digits, so the value reads at a glance. The slot is at least 40 pt wide, and longer values are
     measured so they are not clipped.

     - Parameter symbol: The SF Symbol name, or nil for no icon.
     - Parameter text: The value text.
     - Parameter accent: The alert accent that picks the font and colours.
     - Returns: The image.
     */
    private static func valueImage(symbol: String?, text: String, accent: ReadoutAccent) -> NSImage {
        let font = accent == .warning ? boldFont : textFont
        let width = max(40, textWidth(text, font: font))
        return compose(symbol: symbol, accent: accent, contentWidth: width) { origin, ink in
            drawText(text, at: origin, font: font, color: ink)
        }
    }

    /**
     Draws two lines in the 20 pt canvas: the top line in the upper half, the bottom line in the lower half.

     The slot is sized to the wider line, so long rates like "↑ 1.2 MB/s" are not clipped.

     - Parameter symbol: The SF Symbol name.
     - Parameter top: The upper line.
     - Parameter bottom: The lower line.
     - Parameter accent: The alert accent that picks the font and colours.
     - Returns: The image.
     */
    private static func stackedImage(symbol: String, top: String, bottom: String, accent: ReadoutAccent) -> NSImage {
        let font = accent == .warning ? smallBoldFont : smallFont
        let width = max(textWidth(top, font: font), textWidth(bottom, font: font)) + 2
        return compose(symbol: symbol, accent: accent, contentWidth: width) { origin, ink in
            drawText(top, at: CGPoint(x: origin.x, y: 10), font: font, color: ink)
            drawText(bottom, at: CGPoint(x: origin.x, y: 0), font: font, color: ink)
        }
    }

    /**
     Draws the memory pressure item as an icon only.

     The needle position carries the level. Warning adds a triangle. Critical fills the item red and adds a leading "!".

     Only the normal level is a template, so it matches the bar. Warning and critical carry their own colour.

     - Parameter level: The memory pressure level to draw.
     - Returns: The image. Only the normal level is a template.
     */
    private static func pressureImage(level: MemoryPressureLevel) -> NSImage {
        let accent = pressureAccent(level)
        let ink = foreground(for: accent)
        let icon = symbolImage(MemoryPressureNeedle.symbol(for: level))
        let size = CGSize(width: level == .critical ? 30 : 22, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            var iconX: CGFloat = 2
            if level == .critical {
                let pill = NSBezierPath(roundedRect: CGRect(x: 0, y: 1, width: size.width, height: height - 2),
                                        xRadius: 4, yRadius: 4)
                criticalFill.setFill()
                pill.fill()
                drawText("!", at: CGPoint(x: 3, y: 2), font: boldFont, color: ink)
                iconX = 11
            }
            if let icon {
                tint(icon, ink).draw(in: CGRect(x: iconX, y: 2, width: 14, height: 14))
            }
            if level == .warning, let triangle = symbolImage("exclamationmark.triangle.fill") {
                tint(triangle, ink).draw(in: CGRect(x: 15, y: 3, width: 7, height: 7))
            }
            return true
        }
        image.isTemplate = level == .normal
        return image
    }

    private static func pressureAccent(_ level: MemoryPressureLevel) -> ReadoutAccent {
        switch level {
        case .normal: return .normal
        case .warning: return .warning
        case .critical: return .critical
        }
    }

    // MARK: - Shapes

    /**
     Draws the last 12 levels as vertical bars.

     - Parameter levels: The levels, from 0 to 1, oldest first.
     - Parameter origin: The point where the content starts.
     - Parameter ink: The fill colour.
     */
    private static func drawBars(_ levels: [Double], origin: CGPoint, ink: NSColor) {
        ink.setFill()
        for (index, level) in levels.suffix(12).enumerated() {
            let barHeight = max(1, CGFloat(level) * 14)
            let rect = CGRect(x: origin.x + CGFloat(index) * 3, y: origin.y, width: 2, height: barHeight)
            NSBezierPath(roundedRect: rect, xRadius: 0.5, yRadius: 0.5).fill()
        }
    }

    /**
     Draws a 26 pt wide line through the levels.

     - Parameter levels: The levels, from 0 to 1, oldest first. Nothing is drawn for fewer than two.
     - Parameter origin: The point where the content starts.
     - Parameter ink: The stroke colour.
     */
    private static func drawSparkline(_ levels: [Double], origin: CGPoint, ink: NSColor) {
        guard levels.count > 1 else { return }
        let path = NSBezierPath()
        let width: CGFloat = 26
        for (index, level) in levels.enumerated() {
            let pointX = origin.x + width * CGFloat(index) / CGFloat(levels.count - 1)
            let pointY = origin.y + CGFloat(level) * 14
            let point = CGPoint(x: pointX, y: pointY)
            if index == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        ink.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    /**
     Draws a 14 pt ring with a faint track and an arc for the fraction.

     - Parameter fraction: The filled share of the ring, clamped to 0...1.
     - Parameter origin: The point where the content starts.
     - Parameter ink: The arc colour. The track uses the same colour at 25% alpha.
     */
    private static func drawRing(_ fraction: Double, origin: CGPoint, ink: NSColor) {
        let centre = CGPoint(x: origin.x + 7, y: origin.y + 7)
        let track = NSBezierPath(ovalIn: CGRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12))
        ink.withAlphaComponent(0.25).setStroke()
        track.lineWidth = 2
        track.stroke()

        let arc = NSBezierPath()
        arc.appendArc(withCenter: centre, radius: 6,
                      startAngle: 90, endAngle: 90 - CGFloat(max(0, min(1, fraction))) * 360,
                      clockwise: true)
        ink.setStroke()
        arc.lineWidth = 2
        arc.lineCapStyle = .round
        arc.stroke()
    }

    // MARK: - Composition

    /**
     Lays out an item from left to right: the icon, the warning triangle if any, the drawn content, then optional
     trailing text.

     Critical fills the whole item. The content closure receives its origin and the ink colour for the accent.

     - Parameter symbol: The SF Symbol name for the icon, or nil for no icon.
     - Parameter accent: The alert accent, which picks the ink, the triangle and the fill.
     - Parameter contentWidth: The width reserved for the content, in points.
     - Parameter trailing: Text drawn after the content, or nil.
     - Parameter content: Draws the content at the origin it receives, in the ink colour it receives.
     - Returns: The image. Normal items are templates.
     */
    private static func compose(
        symbol: String?,
        accent: ReadoutAccent,
        contentWidth: CGFloat = 40,
        trailing: String? = nil,
        content: @escaping (CGPoint, NSColor) -> Void
    ) -> NSImage {
        let ink = foreground(for: accent)
        let leading = symbol == nil ? 0 : iconWidth + gap
        let marker = accent == .warning ? markerWidth : 0
        let trailingWidth = trailing.map { gap + textWidth($0, font: textFont) } ?? 0
        let size = CGSize(width: leading + marker + contentWidth + trailingWidth, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            if accent == .critical {
                criticalFill.setFill()
                NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: 4, yRadius: 4).fill()
            }
            if let symbol, let icon = symbolImage(symbol) {
                let rect = CGRect(x: 0, y: (height - icon.size.height) / 2, width: iconWidth, height: icon.size.height)
                tint(icon, ink).draw(in: rect)
            }
            if accent == .warning, let triangle = symbolImage("exclamationmark.triangle.fill") {
                tint(triangle, ink).draw(in: CGRect(x: leading, y: 4, width: 9, height: 9))
            }
            let contentX = leading + marker
            content(CGPoint(x: contentX, y: 3), ink)
            if let trailing {
                drawText(trailing, at: CGPoint(x: contentX + contentWidth + gap, y: 3), font: textFont, color: ink)
            }
            return true
        }
        image.isTemplate = accent == .normal
        return image
    }

    // MARK: - Colour

    /**
     Returns the ink colour for an accent.

     Normal text follows the system label colour. Warning and critical use the alert pairs above.

     - Parameter accent: The alert accent.
     - Returns: The colour to draw with.
     */
    private static func foreground(for accent: ReadoutAccent) -> NSColor {
        switch accent {
        case .normal: return .labelColor
        case .warning: return warningColour
        case .critical: return .white
        }
    }

    /**
     Returns a colour that resolves to `light` or `dark` for the appearance it is drawn in.

     - Parameter light: The colour as `0xRRGGBB` for light appearances.
     - Parameter dark: The colour as `0xRRGGBB` for dark appearances.
     - Returns: The dynamic colour.
     */
    private static func dynamicColour(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return hexColour(isDark ? dark : light)
        }
    }

    private static func hexColour(_ rgb: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1)
    }

    // MARK: - Helpers

    /**
     Returns the named SF Symbol at the status bar's 12 pt regular size.

     - Parameter name: The SF Symbol name.
     - Returns: The image, or nil when the symbol does not exist.
     */
    private static func symbolImage(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    /**
     Returns a copy of an image filled with one colour, keeping its alpha.

     - Parameter image: The image to tint.
     - Parameter color: The colour to fill the image's opaque pixels with.
     - Returns: The tinted copy, or the original image when it cannot be copied.
     */
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
