import AppKit
import Combine
import StatusMonitorCore
import SwiftUI

/**
 Owns the single Settings window.

 The window is created on first use and reused, so reopening it returns to the same place. The app has no Dock icon,
 so the window activates the app explicitly; otherwise it opens behind other apps.
 */
@MainActor
final class SettingsWindowController {
    private let settings: SettingsViewModel
    private let monitor: MonitorViewModel
    private let purge: PurgePermissionViewModel
    private let memoryClean: MemoryCleanViewModel
    private let speedTest: SpeedTestViewModel
    private var window: NSWindow?
    /// Keeps the window's appearance in step with the Appearance setting.
    private var appearanceCancellable: AnyCancellable?
    private let navigation = SettingsNavigation()

    /**
     Creates the controller. The window is not created until `show()` is called.

     - Parameter settings: The settings view model.
     - Parameter monitor: The monitor that supplies the live readings.
     - Parameter purge: The purge approval state.
     - Parameter memoryClean: The clean view model.
     - Parameter speedTest: The speed test view model.
     */
    init(
        settings: SettingsViewModel,
        monitor: MonitorViewModel,
        purge: PurgePermissionViewModel,
        memoryClean: MemoryCleanViewModel,
        speedTest: SpeedTestViewModel
    ) {
        self.settings = settings
        self.monitor = monitor
        self.purge = purge
        self.memoryClean = memoryClean
        self.speedTest = speedTest
    }

    /// Shows the Settings window, creating it on first use, and brings the app to the front.
    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(
                settings: settings, monitor: monitor, purge: purge,
                navigation: navigation, memoryClean: memoryClean, speedTest: speedTest
            ))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "StatusMonitor Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(NSSize(width: 960, height: 680))
            newWindow.center()
            window = newWindow
            appearanceCancellable = settings.$settings
                .map(\.appearance)
                .removeDuplicates()
                .sink { [weak newWindow] mode in newWindow?.appearance = mode.nsAppearance }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
