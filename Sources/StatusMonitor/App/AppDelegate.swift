import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let root = CompositionRoot()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(
            settings: root.settings, monitor: root.monitor, purge: root.purge, memoryClean: root.memoryClean
        )
        root.monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        root.monitor.stop()
    }
}
