import Foundation

/// Runs Auto Clean on each refresh. It asks the pure decision whether to clean, then runs the Standard Clean
/// in the background. A clean is never started while another is still running.
public final class AutoCleanCoordinator {
    public typealias Runner = (_ work: @escaping () -> Void, _ done: @escaping () -> Void) -> Void

    private let purge: PrivilegedPurgeExecutor
    private let clean: MemoryCleanUseCase
    private let lastCleanAt: () -> Double?
    private let recordClean: (Double) -> Void
    private let now: () -> Date
    private let runner: Runner
    private var inFlight = false

    /// `runner` defaults to a background queue. Tests pass a synchronous runner.
    public init(
        purge: PrivilegedPurgeExecutor,
        clean: MemoryCleanUseCase,
        lastCleanAt: @escaping () -> Double?,
        recordClean: @escaping (Double) -> Void,
        now: @escaping () -> Date = Date.init,
        runner: @escaping Runner = { work, done in
            DispatchQueue.global(qos: .utility).async {
                work()
                DispatchQueue.main.async { done() }
            }
        }
    ) {
        self.purge = purge
        self.clean = clean
        self.lastCleanAt = lastCleanAt
        self.recordClean = recordClean
        self.now = now
        self.runner = runner
    }

    /// Checks the threshold and starts a clean if the decision says so. Returns the decision, so the caller can show it.
    @discardableResult
    public func tick(usedPercent: Double, settings: MetricSettings) -> AutoCleanDecision {
        let nowEpoch = now().timeIntervalSince1970
        let decision = AutoCleanDecision.evaluate(
            enabled: settings.autoCleanEnabled,
            usedPercent: usedPercent,
            thresholdPercent: settings.autoCleanThresholdPercent,
            lastCleanAt: lastCleanAt(),
            helperAvailable: purge.isAvailable(),
            nowEpoch: nowEpoch
        )
        guard decision == .clean, !inFlight else { return decision }

        inFlight = true
        let cleanUseCase = clean
        runner({
            _ = cleanUseCase.clean(.standard, trigger: "auto")
        }, { [weak self] in
            guard let self else { return }
            self.recordClean(self.now().timeIntervalSince1970)
            self.inFlight = false
        })
        return decision
    }
}
