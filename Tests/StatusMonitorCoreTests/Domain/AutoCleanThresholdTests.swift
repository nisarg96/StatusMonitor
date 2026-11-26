import Testing
@testable import StatusMonitorCore

@Suite("AvailableMemoryCalculator")
struct AvailableMemoryCalculatorTests {
    @Test("available = (free + inactive + purgeable) pages x page size")
    func formula() {
        let bytes = AvailableMemoryCalculator.availableBytes(
            freePages: 100, inactivePages: 200, purgeablePages: 50, pageSize: 16_384
        )
        #expect(bytes == 350 * 16_384)
    }
}

@Suite("AutoCleanThreshold slider")
struct AutoCleanThresholdTests {
    @Test("the slider runs from 70 to 100 in 5% steps")
    func stops() {
        #expect(AutoCleanThreshold.stops == [70, 75, 80, 85, 90, 95, 100])
    }

    @Test("values outside 70...100 are clamped into it")
    func clamping() {
        #expect(AutoCleanThreshold.snapped(10) == 70)
        #expect(AutoCleanThreshold.snapped(250) == 100)
    }

    @Test("a value between stops snaps to the nearest stop")
    func snapping() {
        #expect(AutoCleanThreshold.snapped(72) == 70)
        #expect(AutoCleanThreshold.snapped(73) == 75)
        #expect(AutoCleanThreshold.snapped(88) == 90)
        #expect(AutoCleanThreshold.snapped(97) == 95)
    }

    @Test("the default is 90%")
    func defaultValue() {
        #expect(AutoCleanThreshold.defaultPercent == 90)
        #expect(AutoCleanThreshold.stops.contains(AutoCleanThreshold.defaultPercent))
    }

    @Test("the label's free-RAM figure: 90% used on 8 GB leaves 0.8 GB free")
    func freeGBLabel() {
        let eightGB: UInt64 = 8 * 1_073_741_824
        #expect(abs(AutoCleanThreshold.freeGBAt(percent: 90, physicalRAMBytes: eightGB) - 0.8) < 0.001)
    }
}

@Suite("AutoCleanDecision")
struct AutoCleanDecisionTests {
    @Test("disabled Auto Clean never cleans")
    func disabled() {
        let d = AutoCleanDecision.evaluate(
            enabled: false, usedPercent: 99, thresholdPercent: 90,
            lastCleanAt: nil, helperAvailable: true, nowEpoch: 1_000
        )
        #expect(d == .skip(reason: .disabled))
    }

    @Test("below the threshold it does not clean")
    func belowThreshold() {
        let d = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 89.9, thresholdPercent: 90,
            lastCleanAt: nil, helperAvailable: true, nowEpoch: 1_000
        )
        #expect(d == .skip(reason: .belowThreshold))
    }

    @Test("at or above the threshold, with the helper available, it cleans")
    func atThreshold() {
        let d = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 90, thresholdPercent: 90,
            lastCleanAt: nil, helperAvailable: true, nowEpoch: 1_000
        )
        #expect(d == .clean)
    }

    @Test("the 180 s cooldown is a hard floor")
    func cooldownFloor() {
        #expect(AutoCleanDecision.cooldownSeconds == 180)
        let within = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 95, thresholdPercent: 90,
            lastCleanAt: 1_000, helperAvailable: true, nowEpoch: 1_179
        )
        #expect(within == .skip(reason: .cooldown))

        let after = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 95, thresholdPercent: 90,
            lastCleanAt: 1_000, helperAvailable: true, nowEpoch: 1_180
        )
        #expect(after == .clean)
    }

    @Test("without the helper it skips with a clear reason")
    func helperMissing() {
        let d = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 95, thresholdPercent: 90,
            lastCleanAt: nil, helperAvailable: false, nowEpoch: 1_000
        )
        #expect(d == .skip(reason: .helperNotAvailable))
    }

    @Test("the helper check is not run unless a clean is otherwise due")
    func helperCheckIsLazy() {
        var helperChecks = 0
        _ = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 50, thresholdPercent: 90,
            lastCleanAt: nil,
            helperAvailable: { helperChecks += 1; return true }(),
            nowEpoch: 1_000
        )
        // The autoclosure is evaluated only when the threshold is met, so this count stays zero.
        #expect(helperChecks == 0)
    }

    @Test("a future last-clean time is refused until clamped and stored")
    func futureLastCleanRefused() {
        let d = AutoCleanDecision.evaluate(
            enabled: true, usedPercent: 95, thresholdPercent: 90,
            lastCleanAt: 9_000, helperAvailable: true, nowEpoch: 1_000
        )
        #expect(d == .skip(reason: .cooldown))
    }
}

@Suite("Auto Clean settings persistence")
struct AutoCleanSettingsTests {
    @Test("the threshold is snapped on the way in, so a stored off-stop value cannot exist")
    func snappedOnInit() {
        #expect(MetricSettings(autoCleanThresholdPercent: 88).autoCleanThresholdPercent == 90)
    }

    @Test("the settings view model stores the snapped slider value")
    func viewModelSnaps() {
        let repo = InMemorySettingsRepository()
        let vm = SettingsViewModel(repository: repo)
        vm.setAutoCleanThresholdPercent(83)
        #expect(vm.settings.autoCleanThresholdPercent == 85)
        #expect(repo.stored.autoCleanThresholdPercent == 85)
    }

    @Test("Auto Clean is off by default")
    func offByDefault() {
        #expect(MetricSettings().autoCleanEnabled == false)
    }
}
