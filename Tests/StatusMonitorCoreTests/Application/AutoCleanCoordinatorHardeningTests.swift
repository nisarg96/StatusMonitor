import Foundation
import Testing
@testable import StatusMonitorCore

/// Mutable clock and stored timestamp, shared by the coordinator closures.
final class CoordinatorClock {
    var epoch: Double
    var storedLastClean: Double?

    init(epoch: Double, storedLastClean: Double? = nil) {
        self.epoch = epoch
        self.storedLastClean = storedLastClean
    }
}

/// Counts availability checks and purge runs. Never touches the system.
final class CoordinatorPurgeDouble: PrivilegedPurgeExecutor {
    var available = true
    private(set) var availabilityChecks = 0
    private(set) var purgeCalls = 0

    func isAvailable() -> Bool {
        availabilityChecks += 1
        return available
    }

    func purge() -> Int32 {
        purgeCalls += 1
        return 0
    }
}

final class CoordinatorPressureDouble: MemoryPressureRunner {
    func run() -> Int32 { 0 }
}

final class CoordinatorNoopLog: RemediationLogWriter {
    func write(_ entry: RemediationLogEntry) {}
}

final class CoordinatorNoMemory: AvailableMemorySource {
    func readAvailableBytes() -> UInt64? { nil }
}

/// Keeps background work until the test runs it, so the caller's thread can be observed.
final class DeferredRunner {
    private(set) var pending: [() -> Void] = []

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

@Suite("AutoCleanCoordinator hardening")
struct AutoCleanCoordinatorHardeningTests {
    private static let settings = MetricSettings(autoCleanEnabled: true, autoCleanThresholdPercent: 90)

    private static func makeCoordinator(
        purge: CoordinatorPurgeDouble,
        clock: CoordinatorClock,
        mono: FakeClock,
        runner: @escaping AutoCleanCoordinator.Runner = { work, done in
            work()
            done()
        }
    ) -> AutoCleanCoordinator {
        let clean = MemoryCleanUseCase(
            purge: purge,
            pressure: CoordinatorPressureDouble(),
            memory: CoordinatorNoMemory(),
            log: CoordinatorNoopLog(),
            now: { Date(timeIntervalSince1970: clock.epoch) },
            recordClean: { clock.storedLastClean = $0 }
        )
        return AutoCleanCoordinator(
            purge: purge,
            clean: clean,
            lastCleanAt: { clock.storedLastClean },
            recordClean: { clock.storedLastClean = $0 },
            monotonic: mono,
            now: { Date(timeIntervalSince1970: clock.epoch) },
            runner: runner
        )
    }

    @Test("a clock moved back keeps Auto Clean working after the cooldown")
    func clockMovedBackDoesNotLockOut() {
        let purge = CoordinatorPurgeDouble()
        let clock = CoordinatorClock(epoch: 900, storedLastClean: 1_000)
        let mono = FakeClock()
        let coordinator = Self.makeCoordinator(purge: purge, clock: clock, mono: mono)
        coordinator.primeAvailability()

        // The first high reading starts the 30 s sustain timer.
        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .skip(reason: .notSustained))
        mono.advance(seconds: 30)
        // The stored clean is in the future. It is clamped to now and stored, so the cooldown restarts from now.
        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .skip(reason: .cooldown))
        #expect(clock.storedLastClean == 900)

        clock.epoch = 900 + AutoCleanDecision.cooldownSeconds
        mono.advance(seconds: 1)
        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .clean)
        #expect(purge.purgeCalls == 1)
    }

    @Test("the availability check never runs on the caller's thread during a tick")
    func tickReadsCacheOnly() {
        let purge = CoordinatorPurgeDouble()
        let clock = CoordinatorClock(epoch: 1_000)
        let mono = FakeClock()
        let deferred = DeferredRunner()
        let coordinator = Self.makeCoordinator(purge: purge, clock: clock, mono: mono, runner: deferred.run)

        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .skip(reason: .notSustained))
        mono.advance(seconds: 30)
        let decision = coordinator.tick(usedPercent: 95, settings: Self.settings)
        #expect(decision == .skip(reason: .helperNotAvailable))
        #expect(purge.availabilityChecks == 0)

        // Once the background priming has run, the cache holds the answer.
        deferred.drain()
        #expect(purge.availabilityChecks == 1)
    }

    @Test("priming at launch makes the first due tick clean without a blocking check")
    func primedAtLaunch() {
        let purge = CoordinatorPurgeDouble()
        let clock = CoordinatorClock(epoch: 1_000)
        let mono = FakeClock()
        let deferred = DeferredRunner()
        let coordinator = Self.makeCoordinator(purge: purge, clock: clock, mono: mono, runner: deferred.run)

        coordinator.primeAvailability()
        deferred.drain()
        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .skip(reason: .notSustained))
        mono.advance(seconds: 30)
        #expect(coordinator.tick(usedPercent: 95, settings: Self.settings) == .clean)
        deferred.drain()
        #expect(purge.purgeCalls == 1)
    }
}
