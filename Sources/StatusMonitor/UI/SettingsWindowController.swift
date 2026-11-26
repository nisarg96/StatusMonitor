import AppKit
import StatusMonitorCore
import SwiftUI

/// Owns the single Settings window. It is created on first use and reused, so reopening it returns to the same place.
/// The app has no Dock icon, so the window activates the app explicitly; otherwise it opens behind other apps.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsViewModel
    private let monitor: MonitorViewModel
    private let purge: PurgePermissionViewModel
    private var window: NSWindow?
    private let navigation = SettingsNavigation()

    init(settings: SettingsViewModel, monitor: MonitorViewModel, purge: PurgePermissionViewModel) {
        self.settings = settings
        self.monitor = monitor
        self.purge = purge
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings, monitor: monitor, purge: purge, navigation: navigation))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "StatusMonitor Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(NSSize(width: 900, height: 620))
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
