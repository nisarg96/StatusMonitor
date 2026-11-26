import Foundation
import Testing
@testable import StatusMonitorCore

/// Counts install and uninstall calls. Never touches sudo and never prompts.
private final class CountingPurgeService: PurgePermissionService {
    var installed = false
    private(set) var installCalls = 0
    private(set) var uninstallCalls = 0

    func isInstalled() -> Bool { installed }

    func install(forUser user: String) throws {
        installCalls += 1
        installed = true
    }

    func uninstall() throws {
        uninstallCalls += 1
        installed = false
    }
}

@Suite("PurgePermissionViewModel initial state")
struct PurgeInitialStateTests {
    @Test("the view model starts in the state it is given")
    func startsInGivenState() {
        let viewModel = PurgePermissionViewModel(
            service: CountingPurgeService(), userName: "nisarg",
            runner: { _, _ in }, initialState: .installed
        )

        #expect(viewModel.state == .installed)
    }

    @Test("without an initial state the view model starts as not installed")
    func defaultsToNotInstalled() {
        let service = CountingPurgeService()
        service.installed = true
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg", runner: { _, _ in })

        #expect(viewModel.state == .notInstalled)
    }

    @Test("with a no-op runner the given state stays, and install or uninstall are never called")
    func noOpRunnerNeverChangesOrInstalls() {
        let service = CountingPurgeService()
        service.installed = true
        let viewModel = PurgePermissionViewModel(
            service: service, userName: "nisarg",
            runner: { _, _ in }, initialState: .installed
        )

        viewModel.refresh()

        #expect(viewModel.state == .installed)
        #expect(service.installCalls == 0)
        #expect(service.uninstallCalls == 0)
    }

    @Test("the snapshot path in the executable never calls install or uninstall")
    func snapshotPathSourceNeverInstalls() throws {
        /// `#filePath` is Tests/StatusMonitorCoreTests/Presentation/<this file>; four levels up is the project root.
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let files = [
            "Sources/StatusMonitor/App/CompositionRoot.swift",
            "Sources/StatusMonitor/CLI/SnapshotCommand.swift"
        ]
        for path in files {
            let text = try String(contentsOf: project.appendingPathComponent(path), encoding: .utf8)
            // "uninstall(" contains "install(", so one check covers both calls.
            #expect(!text.contains("install("), "\(path) calls install or uninstall")
        }
    }
}
