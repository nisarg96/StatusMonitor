import Testing
@testable import StatusMonitorCore

@Suite("Menu bar layout")
struct MenuBarLayoutTests {
    @Test("generation 0 keeps the original autosave names")
    func originalNames() {
        #expect(MenuBarLayoutNaming.autosaveName(for: .cpu, generation: 0) == "StatusMonitor.item.cpu")
    }

    @Test("each generation gets new names, so macOS places the items fresh")
    func newGenerationNames() {
        #expect(MenuBarLayoutNaming.autosaveName(for: .disk, generation: 3) == "StatusMonitor.g3.item.disk")
        #expect(MenuBarLayoutNaming.storedKeys(forGeneration: 2).contains("NSStatusItem Preferred Position StatusMonitor.g2.item.cpu"))
    }

    @Test("candidates include idle items, so they keep their slot")
    func candidatesIncludeIdle() {
        let fakes = FakeSources()
        fakes.disk.counters = DiskCounters(readBytes: 0, writeBytes: 0)
        let settings = SettingsViewModel(repository: InMemorySettingsRepository(MetricSettings(
            collectorOverrides: [.disk: true], hiddenMenuBarItems: [], menuBarItemConfigs: [.disk: MenuBarItemConfig(style: .stacked, hideWhenIdle: true)]
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
