import Foundation

/// Runs Auto Clean on each refresh. It asks the pure decision whether to clean, then runs the Standard Clean in the
/// background. The clean slot lives in the shared `MemoryCleanUseCase`, so a manual clean and an automatic one never
/// overlap.
///
/// The state here (sustain timer, re-arm, cooldown, failures, pause) is in memory and touched only on the main thread.
/// It resets on relaunch. The helper check (`sudo -n -l`) can block, so it never runs on the caller's thread. It is
/// primed in the background by `primeAvailability()`, and each tick reads the cached answer only.
public final class AutoCleanCoordinator {
    public typealias Runner = (_ work: @escaping () -> Void, _ done: @escaping () -> Void) -> Void

    /// A failed or stale helper check is retried no more often than this.
    static let reprobeIntervalSeconds: Double = 60
    private static let nanosecondsPerSecond = 1_000_000_000.0

    private let purge: PrivilegedPurgeExecutor
    private let clean: MemoryCleanUseCase
    private let lastCleanAt: () -> Double?
    private let recordClean: (Double) -> Void
    private let monotonic: MonotonicClock
    private let now: () -> Date
    private let invalidateHelperCache: () -> Void
    private let runner: Runner

    // Main thread only.
    private var armed = true
    private var paused = false
    private var failureCount = 0
    /// Monotonic seconds when used RAM last rose to the threshold. Nil while it is below.
    private var sustainStart: Double?
    /// Monotonic seconds when the current dip below the threshold began. Nil while used RAM is at or above it.
    private var belowSince: Double?
    private var seenCleanCount: Int
    /// The current cooldown from the backoff rule. Starts at the 180 s floor.
    internal private(set) var cooldownSeconds = AutoCleanDecision.cooldownSeconds

    /// Guarded by `stateLock`. Written on a background queue, read on the main thread.
    private let stateLock = NSLock()
    private var helperReady = false
    private var probeInFlight = false
    private var lastProbeEpoch: Double?
    private var pendingOutcome: CleanOutcome?

    /// `runner` defaults to a background queue. Tests pass a synchronous runner.
    /// `invalidateHelperCache` drops the purge executor's own cached availability, so a later check reads the
    /// real state.
    public init(
        purge: PrivilegedPurgeExecutor,
        clean: MemoryCleanUseCase,
        lastCleanAt: @escaping () -> Double?,
        recordClean: @escaping (Double) -> Void,
        monotonic: MonotonicClock,
        now: @escaping () -> Date = Date.init,
        invalidateHelperCache: @escaping () -> Void = {},
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
        self.monotonic = monotonic
        self.now = now
        self.invalidateHelperCache = invalidateHelperCache
        self.runner = runner
        self.seenCleanCount = clean.executedCleanCount
    }

    /// Checks the helper in the background and stores the answer. Returns at once. Call at launch, so the first
    /// due tick already has an answer. A second call while a check is running does nothing.
    public func primeAvailability() {
        stateLock.lock()
        guard !probeInFlight else {
            stateLock.unlock()
            return
        }
        probeInFlight = true
        stateLock.unlock()

        let purge = self.purge
        runner({ [weak self] in
            let ready = purge.isAvailable()
            guard let self else { return }
            self.stateLock.lock()
            self.helperReady = ready
            self.lastProbeEpoch = self.now().timeIntervalSince1970
            self.stateLock.unlock()
        }, { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.probeInFlight = false
            self.stateLock.unlock()
        })
    }

    /// Checks the rules and starts a clean if the decision says so. Returns the decision, so the caller can show it.
    @discardableResult
    public func tick(usedPercent: Double, settings: MetricSettings) -> AutoCleanDecision {
        let nowEpoch = now().timeIntervalSince1970
        let monoNow = Double(monotonic.nanoseconds()) / Self.nanosecondsPerSecond
        let last = clampedLastClean(nowEpoch: nowEpoch)
        updateState(usedPercent: usedPercent, settings: settings, monoNow: monoNow)
        if settings.autoCleanEnabled, !paused, !cachedHelperReady() {
            reprobeIfStale(nowEpoch: nowEpoch)
        }

        var inputs = AutoCleanInputs(
            enabled: settings.autoCleanEnabled,
            usedPercent: usedPercent,
            thresholdPercent: settings.autoCleanThresholdPercent,
            lastCleanAt: last,
            nowEpoch: nowEpoch
        )
        inputs.armed = armed
        inputs.paused = paused
        inputs.cleanInProgress = clean.isCleaning
        inputs.cooldownSeconds = cooldownSeconds
        inputs.sustainStartSeconds = sustainStart
        inputs.monotonicNowSeconds = monoNow
        // The autoclosure reads the cache only. It never spawns a process on the caller's thread.
        let decision = AutoCleanDecision.evaluate(inputs, helperAvailable: cachedHelperReady())
        guard decision == .clean else { return decision }
        return startClean()
    }

    /// A stored clean later than now means the clock moved back. Clamp it to now and store the clamped value, so the
    /// cooldown counts forward from now instead of stalling until the clock catches up.
    private func clampedLastClean(nowEpoch: Double) -> Double? {
        let stored = lastCleanAt()
        guard let stored, stored > nowEpoch else { return stored }
        recordClean(nowEpoch)
        return nowEpoch
    }

    /// Advances the state that depends on this reading: the disarm after any clean (manual ones included), the
    /// re-arm, the sustain timer, the dip timer behind the cooldown reset, and the reset when Auto Clean is turned off.
    /// The cooldown itself returns to the floor only after `cooldownResetBelowSeconds` of continuous dip, never on
    /// the re-arm dip alone.
    private func updateState(usedPercent: Double, settings: MetricSettings, monoNow: Double) {
        let count = clean.executedCleanCount
        if count != seenCleanCount {
            seenCleanCount = count
            armed = false
        }
        let threshold = AutoCleanThreshold.snapped(settings.autoCleanThresholdPercent)
        if AutoCleanDecision.rearms(usedPercent: usedPercent, thresholdPercent: threshold) {
            armed = true
        }
        if usedPercent < Double(threshold) {
            sustainStart = nil
            if belowSince == nil { belowSince = monoNow }
            if AutoCleanDecision.belowLongEnoughToResetCooldown(
                belowSinceSeconds: belowSince, monotonicNowSeconds: monoNow
            ) {
                cooldownSeconds = AutoCleanDecision.cooldownSeconds
            }
        } else {
            belowSince = nil
            if sustainStart == nil { sustainStart = monoNow }
        }
        if !settings.autoCleanEnabled {
            // Turning Auto Clean off clears the pause and the failure count, so turning it on again starts fresh.
            paused = false
            failureCount = 0
            sustainStart = nil
        }
    }

    /// Takes the shared slot on the caller's thread, so a second tick cannot queue a second clean before the first
    /// one starts. The purge runs in the background.
    private func startClean() -> AutoCleanDecision {
        guard clean.reserveCleanSlot() else { return .skip(reason: .cleanInProgress) }
        armed = false
        let cleanUseCase = clean
        runner({ [weak self] in
            let outcome = cleanUseCase.runReservedClean(.standard, trigger: "auto")
            self?.storePendingOutcome(outcome)
        }, { [weak self] in
            guard let self, let outcome = self.takePendingOutcome() else { return }
            self.apply(outcome)
        })
        return .clean
    }

    /// Applies one finished automatic clean. A success resets the failure count and sets the backoff from the freed
    /// memory. A failed purge (non-zero exit, or a timeout, which reports -1) counts toward the pause and drops the
    /// helper cache.
    private func apply(_ outcome: CleanOutcome) {
        guard outcome.skippedReason == nil else {
            // Nothing ran, so nothing to disarm for. Stay armed. The helper was missing when the clean ran, so the
            // coordinator's own flag is stale. Drop it: the next tick re-probes (throttled) instead of cleaning again.
            armed = true
            stateLock.lock()
            helperReady = false
            lastProbeEpoch = nil
            stateLock.unlock()
            return
        }
        if outcome.steps.first?.exitCode == 0 {
            failureCount = 0
            cooldownSeconds = AutoCleanDecision.nextCooldown(
                current: cooldownSeconds, freedBytes: outcome.totalDeltaBytes
            )
            return
        }
        failureCount += 1
        invalidateHelperCache()
        stateLock.lock()
        helperReady = false
        lastProbeEpoch = nil
        stateLock.unlock()
        if failureCount >= AutoCleanDecision.maxConsecutiveFailures {
            paused = true
        }
    }

    private func storePendingOutcome(_ outcome: CleanOutcome) {
        stateLock.lock()
        pendingOutcome = outcome
        stateLock.unlock()
    }

    private func takePendingOutcome() -> CleanOutcome? {
        stateLock.lock()
        defer { stateLock.unlock() }
        let outcome = pendingOutcome
        pendingOutcome = nil
        return outcome
    }

    private func cachedHelperReady() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return helperReady
    }

    /// Starts a new helper check when none has completed recently. A clock moved back also counts as stale.
    private func reprobeIfStale(nowEpoch: Double) {
        stateLock.lock()
        let stale: Bool
        if let last = lastProbeEpoch {
            stale = nowEpoch - last >= Self.reprobeIntervalSeconds || last > nowEpoch
        } else {
            stale = true
        }
        stateLock.unlock()
        if stale {
            primeAvailability()
        }
    }
}
