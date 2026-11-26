import Combine
import Foundation

/**
 Presentation state for the Memory Clean cards and recent-cleans list.

 A clean blocks while purge runs, so the work goes through a runner, as the purge permission row does.
 */
public final class MemoryCleanViewModel: ObservableObject {
    /// Runs `work` somewhere and delivers its outcome to `done` on the main thread.
    public typealias Runner = (_ work: @escaping () -> CleanOutcome, _ done: @escaping (CleanOutcome) -> Void) -> Void

    /// How many finished cleans the list keeps.
    public static let maxRecent = 10

    /// Finished cleans, newest first, capped at `maxRecent`.
    @Published public private(set) var recent: [RecentClean] = []
    /// True while a clean runs. The Clean now buttons are disabled meanwhile.
    @Published public private(set) var isCleaning = false

    private let cleanAction: (CleanPreset) -> CleanOutcome
    private let now: () -> Date
    private let runner: Runner

    /**
     Creates a view model that runs cleans through the given closures.

     - Parameters:
       - clean: Performs a clean for a preset and returns its outcome.
       - now: Returns the current time, stamped on each recent clean.
       - runner: Runs the clean off the main thread. Defaults to `backgroundRunner`.
     */
    public init(
        clean: @escaping (CleanPreset) -> CleanOutcome,
        now: @escaping () -> Date = Date.init,
        runner: @escaping Runner = MemoryCleanViewModel.backgroundRunner
    ) {
        self.cleanAction = clean
        self.now = now
        self.runner = runner
    }

    /// The default runner: does the work on a global background queue and delivers the outcome on the main queue.
    public static let backgroundRunner: Runner = { work, done in
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async { done(result) }
        }
    }

    /**
     Runs one clean.

     Ignored while another clean is running.

     - Parameters:
       - preset: The clean to run.
     */
    public func clean(_ preset: CleanPreset) {
        guard !isCleaning else { return }
        isCleaning = true
        let started = now()
        let action = cleanAction
        runner({ action(preset) }, { [weak self] outcome in
            guard let self else { return }
            self.isCleaning = false
            self.recent.insert(RecentClean(date: started, outcome: outcome), at: 0)
            self.recent = Array(self.recent.prefix(Self.maxRecent))
        })
    }
}
