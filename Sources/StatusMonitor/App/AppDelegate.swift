import AppKit
import StatusMonitorCore

/**
 The application delegate. It builds the status bar, starts sampling, and asks once per launch about purge.
 */
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let root = CompositionRoot()
    private var statusBar: StatusBarController?
    /// The launch-time purge prompt is shown at most once per launch.
    private var purgePromptShownThisLaunch = false

    /**
     Builds the status bar, starts the monitor, and checks the purge helper.

     The check runs off the main thread (the view model's runner), and the prompt is decided only in its completion.

     - Parameter notification: The launch notification. Unused.
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(
            settings: root.settings, monitor: root.monitor, purge: root.purge, memoryClean: root.memoryClean,
            speedTest: root.speedTest
        )
        root.monitor.start()
        root.purge.refresh { [weak self] outcome in
            self?.handlePurgeCheck(outcome)
        }
    }

    /**
     Stops sampling before the app exits.

     - Parameter notification: The termination notification. Unused.
     */
    func applicationWillTerminate(_ notification: Notification) {
        root.monitor.stop()
    }

    /**
     Asks about purge at most once per launch, and only when the helper is missing and the user has not declined before.

     - Parameter outcome: The state the purge check reported.
     */
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

    /**
     Shows the one-time approval prompt. "Install" starts the installer; "Not now" records the choice.

     The prompt is shown only after the check has returned, so the main thread never waits on sudo.
     */
    private func presentPurgePrompt() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow Memory Clean?"
        alert.informativeText = "Memory Clean needs a one-time administrator approval to run purge. "
            + "You can install it now or later from Settings."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not now")
        if alert.runModal() == .alertFirstButtonReturn {
            root.purge.install()
        } else {
            root.remediationStore.purgePermissionPromptDeclined = true
        }
    }
}
