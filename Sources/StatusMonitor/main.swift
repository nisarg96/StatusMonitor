import AppKit
import Foundation
import StatusMonitorCore

// Diagnostic mode: print samples to stdout and exit without starting the GUI.
if let index = CommandLine.arguments.firstIndex(of: "--dump-samples") {
    let count = CommandLine.arguments.indices.contains(index + 1)
        ? Int(CommandLine.arguments[index + 1]) ?? 10
        : 10
    SampleDumpCommand.run(count: count, settings: UserDefaultsSettingsRepository().load())
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    // Accessory policy: no Dock icon and no app menu. LSUIElement in Info.plist does the same for the bundle.
    app.setActivationPolicy(.accessory)
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.run()
}
