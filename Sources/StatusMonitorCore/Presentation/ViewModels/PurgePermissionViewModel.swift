import Combine
import Foundation

/**
 Presentation state for the "Purge permission" row.

 Install and uninstall run off the main thread, because the administrator prompt blocks until the user answers it.
 */
public final class PurgePermissionViewModel: ObservableObject {
    /// The state of the purge permission row.
    public enum State: Equatable, Sendable {
        /// The purge permission is installed.
        case installed
        /// The purge permission is not installed.
        case notInstalled
        /// An install or uninstall is running.
        case working
        /// The last change failed. The associated value is the error's localized description.
        case failed(String)
    }

    /// Runs `work` somewhere and delivers its result to `done` on the main thread.
    public typealias Runner = (_ work: @escaping () -> State, _ done: @escaping (State) -> Void) -> Void

    /// The current state of the row.
    @Published public private(set) var state: State = .notInstalled

    private let service: PurgePermissionService
    private let userName: String
    private let runner: Runner
    /**
     Bumped by every operation. A result from an older operation is dropped, so a late refresh cannot overwrite
     `.working` or a newer change. Only touched on the main thread.
     */
    private var generation = 0

    /**
     Creates the view model for the purge permission row.

     The default runner does the work on a background queue and delivers the result on the main queue. Tests pass a
     synchronous runner, so they see the final state without waiting.

     - Parameters:
       - service: Checks and changes the purge permission.
       - userName: The user name passed to `install(forUser:)`.
       - runner: Runs the check or change off the main thread. Defaults to `backgroundRunner`.
     */
    public init(
        service: PurgePermissionService, userName: String,
        runner: @escaping Runner = PurgePermissionViewModel.backgroundRunner
    ) {
        self.service = service
        self.userName = userName
        self.runner = runner
    }

    /// The default runner: runs `work` on a global background queue and delivers its result on the main queue.
    public static let backgroundRunner: Runner = { work, done in
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async { done(result) }
        }
    }

    /**
     Reads the current state without prompting.

     The check runs through the runner, so `sudo -n -l` never blocks the main thread. Does nothing while an operation
     is working.

     - Parameters:
       - completion: Called on the main thread with this check's outcome, even when a newer operation has since
         replaced `state`.
     */
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

    /**
     Installs the purge permission for the user name given at creation.

     Runs off the main thread. `state` is `.working` until it finishes.
     */
    public func install() {
        let user = userName
        let service = self.service
        performChange {
            try service.install(forUser: user)
        }
    }

    /**
     Removes the purge permission.

     Runs off the main thread. `state` is `.working` until it finishes.
     */
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
