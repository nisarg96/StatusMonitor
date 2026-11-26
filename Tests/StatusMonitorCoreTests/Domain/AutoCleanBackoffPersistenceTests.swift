import Foundation
import Testing
@testable import StatusMonitorCore

// The Auto Clean backoff persists. An ineffective clean doubles the cooldown, and a brief dip below the threshold
// (the re-arm dip) does not reset it. The cooldown returns to 180 s only after an effective clean (256 MiB or more) or
// after 10 minutes of measured monotonic time continuously below the threshold. Uses the fakes in
// AutoCleanTighteningTests.swift. Nothing here touches the system.

@Suite("AutoCleanCoordinator backoff persistence")
struct AutoCleanBackoffPersistenceTests {
    private static let mib: UInt64 = 1_048_576

    /// One automatic clean, with the gap since the last clean at least the current cooldown. The RAM dip lasts 1 s,
    /// so it never reaches the 10-minute reset.
    private func cleanCycle(_ rig: TightenRig) -> AutoCleanDecision {
        rig.advance(rig.coordinator.cooldownSeconds)
        _ = rig.tick(40)
        rig.advance(1)
        _ = rig.tick(95)
        rig.advance(30)
        return rig.tick(95)
    }

    /// Starts the chain with one clean that frees nothing, so the cooldown is 360 s afterwards.
    private func firstIneffectiveClean(_ rig: TightenRig) {
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        _ = rig.tick(95)
    }

    @Test("an ineffective clean doubles the cooldown to 360 s")
    func ineffectiveCleanDoubles() {
        let rig = TightenRig()
        rig.coordinator.primeAvailability()
        _ = rig.tick(95)
        rig.advance(30)
        #expect(rig.tick(95) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 360)
    }

    @Test("a dip shorter than 10 minutes keeps the 360 s cooldown")
    func shortDipKeepsCooldown() {
        let rig = TightenRig()
        firstIneffectiveClean(rig)
        #expect(rig.coordinator.cooldownSeconds == 360)
        rig.advance(10)
        _ = rig.tick(40)                                     // dip starts
        rig.advance(540)
        _ = rig.tick(40)                                     // 540 s below: still short of 10 minutes
        #expect(rig.coordinator.cooldownSeconds == 360)
        rig.advance(10)
        _ = rig.tick(95)                                     // back above the threshold
        #expect(rig.coordinator.cooldownSeconds == 360)
    }

    @Test("10 minutes continuously below the threshold resets the cooldown to 180 s")
    func tenMinutesBelowResets() {
        let rig = TightenRig()
        firstIneffectiveClean(rig)
        rig.advance(10)
        _ = rig.tick(40)                                     // dip starts
        rig.advance(599)
        _ = rig.tick(40)
        #expect(rig.coordinator.cooldownSeconds == 360)      // 599 s below
        rig.advance(1)
        _ = rig.tick(40)
        #expect(rig.coordinator.cooldownSeconds == 180)      // 600 s below
    }

    @Test("an effective clean (256 MiB or more) resets the cooldown to 180 s")
    func effectiveCleanResets() {
        let rig = TightenRig()
        firstIneffectiveClean(rig)
        #expect(rig.coordinator.cooldownSeconds == 360)
        rig.purge.freedPerPurge = 256 * Self.mib
        #expect(cleanCycle(rig) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 180)
    }

    @Test("repeated ineffective cleans double 360, 720, 1440, then cap at 1800 s")
    func cooldownCapsAt1800() {
        let rig = TightenRig()
        firstIneffectiveClean(rig)
        #expect(rig.coordinator.cooldownSeconds == 360)
        #expect(cleanCycle(rig) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 720)
        #expect(cleanCycle(rig) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 1_440)
        #expect(cleanCycle(rig) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 1_800)
        #expect(cleanCycle(rig) == .clean)
        #expect(rig.coordinator.cooldownSeconds == 1_800)
        #expect(rig.purge.purgeCalls == 5)
    }

    @Test("RAM rising back above the threshold before 10 minutes restarts the 10-minute timer")
    func riseRestartsTenMinuteTimer() {
        let rig = TightenRig()
        firstIneffectiveClean(rig)
        rig.advance(10)
        _ = rig.tick(40)                                     // first dip, at 0 s
        rig.advance(500)
        _ = rig.tick(95)                                     // back above the threshold at 500 s: the timer clears
        rig.advance(200)
        _ = rig.tick(40)                                     // second dip, at 700 s
        rig.advance(599)
        _ = rig.tick(40)                                     // 599 s into the second dip, 1,099 s since the first
        #expect(rig.coordinator.cooldownSeconds == 360)
        rig.advance(1)
        _ = rig.tick(40)                                     // 600 s into the second dip
        #expect(rig.coordinator.cooldownSeconds == 180)
    }
}
