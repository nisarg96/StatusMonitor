import Foundation
import Testing
@testable import StatusMonitorCore

// Fakes for the tightened Auto Clean rules. None of them touches the system: the purge double never runs sudo.

/// Wall-clock epoch and the stored last-clean time, shared by the coordinator and the clean use case.
final class TightenClock {
    var epoch: Double = 1_000
    var storedLastClean: Double?
}

/// Available memory, moved by the purge double.
final class TightenMemory: AvailableMemorySource {
    var available: UInt64 = 10_000

    func readAvailableBytes() -> UInt64? { available }
}

/// Frees `freedPerPurge` bytes and returns `exitCode` on each purge. Counts purges and helper-cache invalidations.
final class TightenPurge: PrivilegedPurgeExecutor {
    private let memory: TightenMemory
    /// What `isAvailable` reports. Set to false to make the clean use case skip for a missing helper.
    var available = true
    var exitCode: Int32 = 0
    var freedPerPurge: UInt64 = 0
    /// Runs inside purge(), so a test can start a second clean while the first one is still in flight.
    var onPurge: (() -> Void)?
    private(set) var purgeCalls = 0
    private(set) var availabilityChecks = 0
    private(set) var invalidations = 0

    init(memory: TightenMemory) {
        self.memory = memory
    }

    func isAvailable() -> Bool {
        availabilityChecks += 1
        return available
    }

    func purge() -> Int32 {
        purgeCalls += 1
        onPurge?()
        memory.available &+= freedPerPurge
        return exitCode
    }

    func invalidateAvailability() {
        invalidations += 1
    }
}

final class TightenPressure: MemoryPressureRunner {
    func run() -> Int32 { 0 }
}

final class TightenLog: RemediationLogWriter {
    func write(_ entry: RemediationLogEntry) {}
}

/// Holds background work until the test drains it, so a clean can be in flight while the test acts.
final class TightenDeferredRunner {
    private var pending: [() -> Void] = []

    func run(_ work: @escaping () -> Void, _ done: @escaping () -> Void) {
        pending.append {
            work()
            done()
        }
    }

    func drain() {
        let queued = pending
        pending = []
        queued.forEach { $0() }
    }
}

/// One coordinator, the shared clean use case, and the fakes behind them.
final class TightenRig {
    let clock: TightenClock
    let mono: FakeClock
    let purge: TightenPurge
    let useCase: MemoryCleanUseCase
    let coordinator: AutoCleanCoordinator
    let deferred: TightenDeferredRunner

    init(deferredRunner: Bool = false) {
        let clock = TightenClock()
        let mono = FakeClock()
        let memory = TightenMemory()
        let purge = TightenPurge(memory: memory)
        let deferred = TightenDeferredRunner()
        let now: () -> Date = { Date(timeIntervalSince1970: clock.epoch) }
        let useCase = MemoryCleanUseCase(
            purge: purge, pressure: TightenPressure(), memory: memory, log: TightenLog(),
            now: now, recordClean: { clock.storedLastClean = $0 }
        )
        let runner: AutoCleanCoordinator.Runner = deferredRunner
            ? deferred.run
            : { work, done in work(); done() }
        self.clock = clock
        self.mono = mono
        self.purge = purge
        self.deferred = deferred
        self.useCase = useCase
        self.coordinator = AutoCleanCoordinator(
            purge: purge,
            clean: useCase,
            lastCleanAt: { clock.storedLastClean },
            recordClean: { clock.storedLastClean = $0 },
            monotonic: mono,
            now: now,
            invalidateHelperCache: { purge.invalidateAvailability() },
            runner: runner
        )
    }

    /// Ticks at `percent` used RAM, with Auto Clean on (or off) at the default threshold.
    func tick(_ percent: Double, enabled: Bool = true) -> AutoCleanDecision {
        coordinator.tick(usedPercent: percent, settings: MetricSettings(autoCleanEnabled: enabled))
    }

    /// Moves the wall clock and the monotonic clock together.
    func advance(_ seconds: Double) {
        clock.epoch += seconds
        mono.advance(seconds: seconds)
    }

    /// One automatic clean from a settled state. RAM dips below the re-arm line, then rises and stays up for 30 s.
    /// The wall clock moves at least 200 s first, and at least the current cooldown, so any cooldown from an earlier
    /// clean has passed. Ineffective cleans double the cooldown, so the wait follows it.
    func autoCycle() -> AutoCleanDecision {
        advance(max(200, coordinator.cooldownSeconds))
        _ = tick(40)
        advance(1)
        _ = tick(95)
        advance(30)
        return tick(95)
    }
}

@Suite("AutoCleanCoordinator tightening")
struct AutoCleanCoordinatorTighteningTests {
    @Test("a spike shorter than 30 s does not clean")
    func shortSpike() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        #expect(rig.tick(95) == .skip(reason: .notSustained))
        rig.advance(29)
        #expect(rig.tick(95) == .skip(reason: .notSustained))
        #expect(rig.purge.purgeCalls == 0)
    }

    @Test("a rise held for 30 s cleans")
    func sustainedRiseCleans() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)
        #expect(rig.purge.purgeCalls == 1)
    }

    @Test("a dip below the threshold resets the 30 s timer")
    func dipResetsSustain() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)                                            // timer starts at 0 s
        rig.advance(20)
        #expect(rig.tick(80) == .skip(reason: .belowThreshold))     // dip at 20 s resets it
        rig.advance(15)
        #expect(rig.tick(95) == .skip(reason: .notSustained))       // restarts at 35 s
        rig.advance(20)
        #expect(rig.tick(95) == .skip(reason: .notSustained))       // 20 s since the restart
        rig.advance(10)
        #expect(rig.tick(95) == .clean)                             // 30 s since the restart
    }

    @Test("after a clean, no second clean until RAM falls below threshold minus 5")
    func rearmHysteresis() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)
        rig.advance(400)  // the 360 s cooldown after the ineffective clean has passed: only the re-arm rule can block
        #expect(rig.tick(95) == .skip(reason: .waitingForRearm))
        #expect(rig.tick(80) == .skip(reason: .waitingForRearm))   // exactly threshold minus 5 does not re-arm
        #expect(rig.tick(79.9) == .skip(reason: .belowThreshold))  // below the re-arm line: re-armed
        rig.advance(1)
        #expect(rig.tick(95) == .skip(reason: .notSustained))
        rig.advance(30)
        #expect(rig.tick(95) == .clean)
        #expect(rig.purge.purgeCalls == 2)
    }

    @Test("an ineffective clean doubles the cooldown to 360 s, and a brief dip below the threshold keeps it")
    func ineffectiveCleanDoublesCooldown() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)              // frees nothing
        #expect(rig.coordinator.cooldownSeconds == 360)
        rig.advance(10)
        _ = rig.tick(40)                             // RAM falls below the threshold (re-arm dip)
        #expect(rig.coordinator.cooldownSeconds == 360)
    }

    @Test("an effective clean keeps the cooldown at 180 s")
    func effectiveCleanKeepsCooldown() {
        let rig = TightenRig()
        rig.purge.freedPerPurge = 256 * 1024 * 1024
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 180)
    }

    @Test("three failed cleans pause Auto Clean and invalidate the helper cache")
    func threeFailuresPause() {
        let rig = TightenRig()
        rig.purge.exitCode = 1
        rig.coordinator.primeAvailability()
        #expect(rig.autoCycle() == .clean)              // failure 1
        let afterFirst = rig.purge.availabilityChecks
        _ = rig.tick(40)
        #expect(rig.purge.availabilityChecks == afterFirst + 1)   // the dropped cache was re-read
        #expect(rig.autoCycle() == .clean)              // failure 2
        #expect(rig.autoCycle() == .clean)              // failure 3
        #expect(rig.purge.invalidations == 3)
        let checks = rig.purge.availabilityChecks
        #expect(rig.autoCycle() == .skip(reason: .paused))
        #expect(rig.purge.purgeCalls == 3)
        #expect(rig.purge.availabilityChecks == checks)  // paused: the helper is not re-checked
    }

    @Test("a timed-out purge (exit -1) counts as a failure")
    func timeoutCountsAsFailure() {
        let rig = TightenRig()
        rig.purge.exitCode = -1
        rig.coordinator.primeAvailability()
        _ = rig.autoCycle()
        _ = rig.autoCycle()
        _ = rig.autoCycle()
        #expect(rig.autoCycle() == .skip(reason: .paused))
    }

    @Test("a successful purge resets the failure count")
    func successResetsFailures() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        rig.purge.exitCode = 1
        _ = rig.autoCycle()
        _ = rig.autoCycle()
        rig.purge.exitCode = 0
        #expect(rig.autoCycle() == .clean)              // success resets the count
        rig.purge.exitCode = 1
        #expect(rig.autoCycle() == .clean)              // failure 1
        #expect(rig.autoCycle() == .clean)              // failure 2
        #expect(rig.autoCycle() == .clean)              // failure 3
        #expect(rig.autoCycle() == .skip(reason: .paused))
    }

    @Test("turning Auto Clean off and on again clears the pause")
    func toggleUnpauses() {
        let rig = TightenRig()
        rig.purge.exitCode = 1
        rig.coordinator.primeAvailability()
        _ = rig.autoCycle()
        _ = rig.autoCycle()
        _ = rig.autoCycle()
        #expect(rig.autoCycle() == .skip(reason: .paused))
        #expect(rig.tick(95, enabled: false) == .skip(reason: .disabled))
        rig.purge.exitCode = 0
        #expect(rig.autoCycle() == .clean)
    }

    @Test("a clean skipped for a missing helper stays armed and does not repeat every tick")
    func skippedCleanKeepsArmed() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        rig.purge.available = false                  // the cache still says yes, but the use case finds no helper
        #expect(rig.tick(95) == .clean)
        #expect(rig.purge.purgeCalls == 0)
        // The skip dropped the stale flag, so the next tick re-probes and sees no helper. It does not clean again.
        #expect(rig.tick(95) == .skip(reason: .helperNotAvailable))
        #expect(rig.purge.purgeCalls == 0)
        rig.purge.available = true
        rig.advance(60)                              // the re-probe is throttled for 60 s
        #expect(rig.tick(95) == .clean)
        #expect(rig.purge.purgeCalls == 1)
    }

    @Test("a manual clean in flight blocks Auto Clean")
    func manualBlocksAuto() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        var during: AutoCleanDecision?
        rig.purge.onPurge = { during = rig.tick(95) }
        let outcome = rig.useCase.clean(.standard, trigger: "manual")
        #expect(outcome.skippedReason == nil)
        #expect(during == .skip(reason: .cleanInProgress))
        #expect(rig.purge.purgeCalls == 1)
    }

    @Test("an automatic clean in flight blocks a manual clean")
    func autoBlocksManual() {
        let rig = TightenRig(deferredRunner: true)
        rig.coordinator.primeAvailability()
        rig.deferred.drain()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)                              // queued, not yet run
        #expect(rig.tick(95) == .skip(reason: .cleanInProgress))     // a second tick does not queue another
        let manual = rig.useCase.clean(.standard, trigger: "manual")
        #expect(manual.skippedReason == "a clean is already running")
        #expect(rig.purge.purgeCalls == 0)
        rig.deferred.drain()
        #expect(rig.purge.purgeCalls == 1)
    }

    @Test("a manual clean disarms Auto Clean and starts the cooldown")
    func manualCleanStartsCooldownAndDisarms() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.useCase.clean(.standard, trigger: "manual")
        #expect(rig.clock.storedLastClean == 1_000)
        #expect(rig.tick(95) == .skip(reason: .waitingForRearm))
        rig.advance(50)
        #expect(rig.tick(40) == .skip(reason: .belowThreshold))      // re-arms
        rig.advance(1)
        #expect(rig.tick(95) == .skip(reason: .notSustained))
        rig.advance(30)                                              // 1081, inside the cooldown from 1000
        #expect(rig.tick(95) == .skip(reason: .cooldown))
        rig.advance(99)                                              // 1180
        #expect(rig.tick(95) == .clean)
        #expect(rig.purge.purgeCalls == 2)
    }

    @Test("a manual failure does not change the failure count or the backoff")
    func manualFailureDoesNotCount() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        rig.purge.exitCode = 1
        _ = rig.useCase.clean(.standard, trigger: "manual")
        #expect(rig.coordinator.cooldownSeconds == 180)
        #expect(rig.autoCycle() == .clean)              // automatic failure 1
        #expect(rig.autoCycle() == .clean)              // automatic failure 2
        #expect(rig.autoCycle() == .clean)              // automatic failure 3: the manual one did not count
        #expect(rig.autoCycle() == .skip(reason: .paused))
    }

    @Test("the default threshold is 85%, so 84% is below it and 85% starts the timer")
    func defaultThreshold() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        #expect(rig.tick(84) == .skip(reason: .belowThreshold))
        #expect(rig.tick(85) == .skip(reason: .notSustained))
    }
}
