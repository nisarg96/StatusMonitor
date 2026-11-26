import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("MonitorViewModel timed history")
struct TimedHistoryWiringTests {
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

    @Test("paired series share each refresh's wall-clock time, and match the plain histories")
    func sharedTickTime() {
        let rig = Rig()
        rig.monitor.setPopoverOpen(true)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 0, tx: 0)]
        let before = Date()
        rig.monitor.refresh()
        rig.fakes.clock.advance(seconds: 2)
        rig.monitor.refresh()
        let after = Date()

        let down = rig.monitor.timedHistories[.networkDown]
        let upload = rig.monitor.timedHistories[.networkUp]
        #expect(down?.samples.count == 2)
        #expect(down?.times == upload?.times)
        #expect(down?.values == rig.monitor.histories[.networkDown]?.values)
        #expect((down?.times ?? []).allSatisfy { $0 >= before && $0 <= after })
    }
}
