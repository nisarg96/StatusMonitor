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
    private let memoryClean: MemoryCleanViewModel
    private var window: NSWindow?
    private let navigation = SettingsNavigation()

    init(
        settings: SettingsViewModel,
        monitor: MonitorViewModel,
        purge: PurgePermissionViewModel,
        memoryClean: MemoryCleanViewModel
    ) {
        self.settings = settings
        self.monitor = monitor
        self.purge = purge
        self.memoryClean = memoryClean
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(
                settings: settings, monitor: monitor, purge: purge,
                navigation: navigation, memoryClean: memoryClean
            ))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "StatusMonitor Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(NSSize(width: 960, height: 680))
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
