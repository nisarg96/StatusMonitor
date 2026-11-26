import AppKit
import Foundation
import StatusMonitorCore

// Diagnostic mode: print samples to stdout and exit without starting the GUI.
switch DumpSamplesArguments.parse(CommandLine.arguments) {
case .success(nil):
    break
case .success(let count?):
    let dependencies = CompositionRoot.sampleDumpDependencies()
    SampleDumpCommand.run(count: count, sources: dependencies.sources, settings: dependencies.settings)
    exit(0)
case .failure(let error):
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(2)
}

// Snapshot mode: render the real views to PNG files in a folder, then exit. Nothing is started or cleaned.
switch SnapshotArguments.parse(CommandLine.arguments) {
case .success(nil):
    break
case .success(let folder?):
    do {
        try MainActor.assumeIsolated {
            try SnapshotCommand.run(folder: folder, root: SnapshotCommand.makeRoot())
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data(("--snapshot failed: \(error.localizedDescription)\n").utf8))
        exit(1)
    }
case .failure(let error):
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(2)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    // Accessory policy: no Dock icon and no app menu. LSUIElement in Info.plist does the same for the bundle.
    app.setActivationPolicy(.accessory)
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.run()
}
