import AppKit
import StatusMonitorCore
import SwiftUI

extension AppearanceMode {
    /// The SwiftUI colour scheme for this mode, or nil to follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The name of this mode in the Settings theme picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

extension AppearanceMode {
    /**
     The AppKit appearance that matches this setting, so native controls and SwiftUI colours agree.

     `system` returns nil, which means the window follows the Mac's appearance.
     */
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
