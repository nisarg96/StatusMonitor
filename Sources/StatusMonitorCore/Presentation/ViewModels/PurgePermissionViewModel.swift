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

    /// The default runner does the work on a background queue and delivers the result on the main queue.
    /// Tests pass a synchronous runner, so they see the final state without waiting.
    public init(service: PurgePermissionService, userName: String, runner: @escaping Runner = PurgePermissionViewModel.backgroundRunner) {
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

    /// Reads the current state. Never prompts.
    public func refresh() {
        state = service.isInstalled() ? .installed : .notInstalled
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
        let service = self.service
        runner({
            do {
                try change()
                return service.isInstalled() ? .installed : .notInstalled
            } catch {
                return .failed(error.localizedDescription)
            }
        }, { [weak self] outcome in
            self?.state = outcome
        })
    }
}
