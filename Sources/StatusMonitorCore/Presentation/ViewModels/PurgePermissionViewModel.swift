import Combine
import Foundation

/// Presentation state for the "Purge permission" row. Install and uninstall run off the main thread,
/// because the administrator prompt blocks until the user answers it.
public final class PurgePermissionViewModel: ObservableObject {
    public enum State: Equatable, Sendable {
        case installed
        case notInstalled
        case working
        case failed(String)
    }

    /// Runs `work` somewhere and delivers its result to `done` on the main thread.
    public typealias Runner = (_ work: @escaping () -> State, _ done: @escaping (State) -> Void) -> Void

    @Published public private(set) var state: State = .notInstalled

    private let service: PurgePermissionService
    private let userName: String
    private let runner: Runner
    /// Bumped by every operation. A result from an older operation is dropped, so a late refresh cannot
    /// overwrite `.working` or a newer change. Only touched on the main thread.
    private var generation = 0

    /// The default runner does the work on a background queue and delivers the result on the main queue.
    /// Tests pass a synchronous runner, so they see the final state without waiting.
    public init(
        service: PurgePermissionService, userName: String,
        runner: @escaping Runner = PurgePermissionViewModel.backgroundRunner
    ) {
        self.service = service
        self.userName = userName
        self.runner = runner
    }

    public static let backgroundRunner: Runner = { work, done in
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async { done(result) }
        }
    }

    /// Reads the current state. Never prompts. The check runs through the runner, so `sudo -n -l`
    /// never blocks the main thread. `completion`, if given, runs on the main thread with this check's outcome,
    /// even when a newer operation has since replaced `state`.
    public func refresh(completion: ((State) -> Void)? = nil) {
        guard state != .working else { return }
        generation += 1
        let token = generation
        let service = self.service
        runner({
            service.isInstalled() ? .installed : .notInstalled
        }, { [weak self] outcome in
            if let self, self.generation == token {
                self.state = outcome
            }
            completion?(outcome)
        })
    }

    public func install() {
        let user = userName
        let service = self.service
        performChange {
            try service.install(forUser: user)
        }
    }

    public func uninstall() {
        let service = self.service
        performChange {
            try service.uninstall()
        }
    }

    private func performChange(_ change: @escaping () throws -> Void) {
        state = .working
        generation += 1
        let token = generation
        let service = self.service
        runner({
            do {
                try change()
                return service.isInstalled() ? .installed : .notInstalled
            } catch {
                return .failed(error.localizedDescription)
            }
        }, { [weak self] outcome in
            guard let self, self.generation == token else { return }
            self.state = outcome
        })
    }
}
