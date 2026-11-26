import Testing
@testable import StatusMonitorCore

@Suite("MonitorViewModel traffic totals")
struct TrafficAccumulationTests {
    private struct Rig {
        let fakes = FakeSources()
        let scheduler = FakeRefreshScheduler()
        let monitor: MonitorViewModel

        init() {
            let settings = SettingsViewModel(repository: InMemorySettingsRepository())
            monitor = MonitorViewModel(
                useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
                settings: settings,
                scheduler: scheduler,
                physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
            )
        }
    }

    @Test("a steady 2 s tick adds the bytes that actually moved")
    func steadyTickAddsBytes() {
        let rig = Rig()
        rig.monitor.setPopoverOpen(true)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 0, tx: 0)]
        rig.monitor.refresh()                          // baseline

        rig.fakes.clock.advance(seconds: 2)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 2_000, tx: 500)]
        rig.monitor.refresh()

        #expect(rig.monitor.dailyTraffic?.downBytes == 2_000)
        #expect(rig.monitor.dailyTraffic?.upBytes == 500)
    }

    @Test("after a long sleep, the total counts the bytes moved, not rate times the nominal interval")
    func sleepGapIsNotUnderCounted() {
        let rig = Rig()
        rig.monitor.setPopoverOpen(true)                // nominal interval 2 s
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 0, tx: 0)]
        rig.monitor.refresh()

        // The Mac sleeps for 60 s; 6_000 bytes move over that window.
        rig.fakes.clock.advance(seconds: 60)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 6_000, tx: 0)]
        rig.monitor.refresh()

        // Rate times the nominal 2 s would give 200 bytes. The real figure is 6_000.
        #expect(rig.monitor.dailyTraffic?.downBytes == 6_000)
    }
}
