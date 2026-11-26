import AppKit
import SwiftUI

/**
 Colours for the Settings window.

 Each token is a light and dark pair. Light values are the spec's hex values, dark values are derived from them, and
 they resolve per appearance at draw time.
 */
enum SettingsPalette {
    /// Selected sidebar row and toggles. Light is #0F7A5F. Dark is a deeper teal, so white text keeps about 5:1.
    static let accent = dynamic(light: 0x0F7A5F, dark: 0x1C7D62)
    /// Text on the accent fill. White in both modes.
    static let onAccent = Color.white
    /// The fill of the selected style chip. #1D1D1F in light mode, inverted in dark mode.
    static let chipSelected = dynamic(light: 0x1D1D1F, dark: 0xF2F2F4)
    /// The text of the selected style chip, which contrasts with `chipSelected`.
    static let chipSelectedText = dynamic(light: 0xFFFFFF, dark: 0x1D1D1F)
    /// Sidebar ground, #F3F3F5 in light.
    static let sidebar = dynamic(light: 0xF3F3F5, dark: 0x25282E)
    /// The fill of the Memory Clean note box.
    static let noteFill = dynamic(light: 0xF2F5F8, dark: 0x1C2833)
    /// The border of the Memory Clean note box.
    static let noteBorder = dynamic(light: 0xDCE3EA, dark: 0x34495C)
    /// The text of the Memory Clean note box.
    static let noteText = dynamic(light: 0x24425F, dark: 0xC5D6E8)
    /// The fill of the "Installed" pill.
    static let pillFill = dynamic(light: 0xE3F5EF, dark: 0x173D33)
    /// The text of the "Installed" pill.
    static let pillText = dynamic(light: 0x0A5A46, dark: 0x7FE6C8)
    /// The light menu bar specimen. It is fixed, because the previews show both bar appearances on purpose.
    static let previewLight = Color(nsColor: NSColor(srgbHex: 0xECECEE))
    /// The dark menu bar specimen. It is fixed, because the previews show both bar appearances on purpose.
    static let previewDark = Color(nsColor: NSColor(srgbHex: 0x2B2F36))

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(srgbHex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    /// Creates an opaque sRGB colour from a 24-bit hex value.
    convenience init(srgbHex value: UInt32) {
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
