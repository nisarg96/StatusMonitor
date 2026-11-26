import Testing
@testable import StatusMonitorCore

@Suite("Menu bar layout")
struct MenuBarLayoutTests {
    @Test("candidates include idle items, so they keep their slot")
    func candidatesIncludeIdle() {
        let fakes = FakeSources()
        fakes.disk.counters = DiskCounters(readBytes: 0, writeBytes: 0)
        let settings = SettingsViewModel(repository: InMemorySettingsRepository(MetricSettings(
            collectorOverrides: [.disk: true], hiddenMenuBarItems: [],
            menuBarItemConfigs: [.disk: MenuBarItemConfig(style: .stacked, hideWhenIdle: true)]
        )))
        let monitor = MonitorViewModel(
            useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
            settings: settings,
            scheduler: FakeRefreshScheduler()
        )
        monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        monitor.refresh()
        #expect(monitor.candidateItems.contains(.disk))
    }
}
