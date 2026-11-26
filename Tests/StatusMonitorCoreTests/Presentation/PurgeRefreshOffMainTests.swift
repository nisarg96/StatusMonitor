import Foundation
import Testing
@testable import StatusMonitorCore

/// Records every `isInstalled()` call and the thread it ran on. Never touches sudo.
private final class RecordingPurgeService: PurgePermissionService {
    private let lock = NSLock()
    private var calls = 0
    private var mainThreadCalls = 0
    private(set) var callThreads: [Thread] = []
    var installed = false
    let called = DispatchSemaphore(value: 0)

    var callCount: Int { lock.lock(); defer { lock.unlock() }; return calls }
    var mainThreadCallCount: Int { lock.lock(); defer { lock.unlock() }; return mainThreadCalls }

    func isInstalled() -> Bool {
        lock.lock()
        calls += 1
        if Thread.isMainThread { mainThreadCalls += 1 }
        callThreads.append(Thread.current)
        let result = installed
        lock.unlock()
        called.signal()
        return result
    }

    func install(forUser user: String) throws { installed = true }
    func uninstall() throws { installed = false }
}

/// Holds the work and completion handed to the runner, so the test decides when the work runs.
private final class GateRunner {
    private(set) var pendingWork: (() -> PurgePermissionViewModel.State)?
    private(set) var pendingDone: ((PurgePermissionViewModel.State) -> Void)?

    lazy var runner: PurgePermissionViewModel.Runner = { [weak self] work, done in
        self?.pendingWork = work
        self?.pendingDone = done
    }
}

@Suite("PurgePermissionViewModel.refresh runs off the main thread")
struct PurgeRefreshOffMainTests {
    @Test("refresh hands the check to the runner and does not call isInstalled on the caller")
    func refreshDoesNotCheckSynchronously() {
        let service = RecordingPurgeService()
        service.installed = true
        let gate = GateRunner()
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg", runner: gate.runner)

        viewModel.refresh()

        #expect(service.callCount == 0)
        #expect(viewModel.state == .notInstalled)
        #expect(gate.pendingWork != nil)
    }

    @Test("the result from refresh is published only through done")
    func refreshPublishesThroughDone() {
        let service = RecordingPurgeService()
        service.installed = true
        let gate = GateRunner()
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg", runner: gate.runner)

        viewModel.refresh()
        let outcome = gate.pendingWork?()
        #expect(viewModel.state == .notInstalled)
        gate.pendingDone?(outcome ?? .failed("no work"))

        #expect(viewModel.state == .installed)
        #expect(service.callCount == 1)
    }

    @Test("with the default background runner, isInstalled never runs on the main thread")
    func defaultRunnerChecksOffMain() {
        let service = RecordingPurgeService()
        let viewModel = PurgePermissionViewModel(service: service, userName: "nisarg")
        let caller = Thread.current

        viewModel.refresh()

        let finished = service.called.wait(timeout: .now() + 5)
        #expect(finished == .success)
        #expect(service.mainThreadCallCount == 0)
        #expect(service.callThreads.allSatisfy { $0 != caller })
    }
}
