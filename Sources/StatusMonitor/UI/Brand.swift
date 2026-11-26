import SwiftUI

/// The app icon's palette. Cards, Settings icons and warnings use these, so the UI matches the icon.
enum Brand {
    /// The icon's teal accent (#2BD4A4).
    static let accent = Color(red: 0x2B / 255, green: 0xD4 / 255, blue: 0xA4 / 255)
    /// The icon's warm orange (#FF8A3D), used for warnings.
    static let warm = Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x3D / 255)
}
