import AppKit
import StatusMonitorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let root = CompositionRoot()
    private var statusBar: StatusBarController?
    /// The launch-time purge prompt is shown at most once per launch.
    private var purgePromptShownThisLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(
            settings: root.settings, monitor: root.monitor, purge: root.purge, memoryClean: root.memoryClean
        )
        root.monitor.start()
        // The check runs off the main thread (the view model's runner). The prompt is decided only in its completion.
        root.purge.refresh { [weak self] outcome in
            self?.handlePurgeCheck(outcome)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        root.monitor.stop()
    }

    private func handlePurgeCheck(_ outcome: PurgePermissionViewModel.State) {
        let installed: Bool?
        switch outcome {
        case .installed: installed = true
        case .notInstalled: installed = false
        case .working, .failed: installed = nil
        }
        guard !purgePromptShownThisLaunch,
              PurgePermissionPromptPolicy.shouldAsk(
                  installed: installed, declinedBefore: root.remediationStore.purgePermissionPromptDeclined
              )
        else { return }
        purgePromptShownThisLaunch = true
        presentPurgePrompt()
    }

    private func presentPurgePrompt() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow Memory Clean?"
        alert.informativeText = "Memory Clean needs a one-time administrator approval to run purge. "
            + "You can install it now or later from Settings."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not now")
        // Shown only after the check has returned, so the main thread never waits on sudo.
        if alert.runModal() == .alertFirstButtonReturn {
            root.purge.install()
        } else {
            root.remediationStore.purgePermissionPromptDeclined = true
        }
    }
}
