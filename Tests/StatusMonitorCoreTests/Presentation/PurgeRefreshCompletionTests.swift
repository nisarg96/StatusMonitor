import Testing
@testable import StatusMonitorCore

/// Scripted installer state for the completion tests. It never touches sudo and never prompts.
private final class ScriptedPurgeService: PurgePermissionService {
    var installed = false

    func isInstalled() -> Bool { installed }
    func install(forUser user: String) throws { installed = true }
    func uninstall() throws { installed = false }
}

@Suite("PurgePermissionViewModel.refresh completion")
struct PurgeRefreshCompletionTests {
    @Test("the completion receives the installed outcome of the check")
    func completionReportsInstalled() {
        let service = ScriptedPurgeService()
        service.installed = true
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg", runner: { work, done in
            done(work())
        })

        var received: [PurgePermissionViewModel.State] = []
        viewModel.refresh { received.append($0) }

        #expect(received == [.installed])
        #expect(viewModel.state == .installed)
    }

    @Test("the completion receives the not-installed outcome, and runs only after the work")
    func completionWaitsForWork() {
        let service = ScriptedPurgeService()
        var pendingWork: (() -> PurgePermissionViewModel.State)?
        var pendingDone: ((PurgePermissionViewModel.State) -> Void)?
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg", runner: { work, done in
            pendingWork = work
            pendingDone = done
        })

        var received: [PurgePermissionViewModel.State] = []
        viewModel.refresh { received.append($0) }
        #expect(received.isEmpty)

        let outcome = pendingWork?() ?? .failed("no work")
        pendingDone?(outcome)

        #expect(received == [.notInstalled])
        #expect(viewModel.state == .notInstalled)
    }
}
