import AppKit
import StatusMonitorCore
import SwiftUI

/// Popover colours. Every token is a light and dark pair, resolved per appearance.
/// Light values are the spec's hex values. Dark values come from the app's dark palette (the icon colours in `Brand`)
/// or are derived from the light value to keep it readable on a dark ground.
enum PopoverPalette {
    static let ground = pair(light: 0xE4E7EB, dark: 0x15171A)
    static let card = pair(light: 0xFBFBFC, dark: 0x22252A)
    static let cardBorder = dynamic(light: NSColor(white: 0, alpha: 0.12), dark: NSColor(white: 1, alpha: 0.12))
    static let text = pair(light: 0x1D1D1F, dark: 0xF2F2F4)
    static let secondaryText = pair(light: 0x5F6368, dark: 0xA3A8B0)
    static let divider = pair(light: 0xE4E5E8, dark: 0x3A3E45)
    static let track = divider
    /// Bar fill and the upload sparkline.
    static let fill = pair(light: 0x14A37F, dark: 0x2BD4A4)
    /// Checkboxes and the upload arrow.
    static let accent = pair(light: 0x0F7A5F, dark: 0x2BD4A4)
    /// Download sparkline (dashed).
    static let download = pair(light: 0xE0661A, dark: 0xFF8A3D)
    /// Download arrow.
    static let downloadArrow = pair(light: 0xB4530F, dark: 0xFF9F5A)
    static let warning = pair(light: 0xB4530F, dark: 0xFF9F5A)
    static let critical = pair(light: 0xC62828, dark: 0xFF6B6B)
    static let primaryFill = pair(light: 0x1D1D1F, dark: 0xF2F2F4)
    static let primaryText = pair(light: 0xFFFFFF, dark: 0x1D1D1F)
    static let secondaryFill = pair(light: 0xFFFFFF, dark: 0x2B2F36)
    static let secondaryBorder = pair(light: 0xC9CBD0, dark: 0x4A4F58)
    static let tooltipFill = pair(light: 0xFFFFFF, dark: 0x2B2F36)

    /// The colour for a readout value. Normal uses the default text colour.
    static func color(for accent: ReadoutAccent?) -> Color {
        switch accent {
        case .warning: return warning
        case .critical: return critical
        case .normal, nil: return text
        }
    }

    private static func pair(light: UInt32, dark: UInt32) -> Color {
        dynamic(light: nsColor(light), dark: nsColor(dark))
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
