import Testing
@testable import StatusMonitorCore

@Suite("Empty state before the first sample")
struct EmptyStateTests {
    private let sampled = SystemSnapshot(
        cpuPercent: 42, memoryUsedBytes: 1_073_741_824, downBps: 2048, upBps: 512
    )
    private let unsampled = SystemSnapshot(isSampled: false)

    @Test("a snapshot built by hand counts as sampled")
    func handBuiltIsSampled() {
        #expect(SystemSnapshot().isSampled)
    }

    @Test("an unsampled snapshot draws no glyph, so the item shows its icon alone")
    func noGlyphWithoutSample() {
        #expect(glyphOf(.cpu, unsampled) == nil)
        #expect(glyphOf(.ram, unsampled) == nil)
        #expect(glyphOf(.network, unsampled) == nil)
        #expect(glyphOf(.cpu, sampled) != nil)
    }

    @Test("an unsampled snapshot has no menu bar value segment and the fallback title is SM")
    func noSegmentWithoutSample() {
        let settings = MetricSettings()
        #expect(MenuBarItemFormatter.segment(for: .cpu, snapshot: unsampled, settings: settings) == nil)
        #expect(MenuBarItemFormatter.segment(for: .network, snapshot: unsampled, settings: settings) == nil)
        #expect(StatusTitleFormatter.title(for: unsampled, settings: settings) == "SM")
    }

    @Test("the popover shows -- for CPU, RAM and network before the first sample")
    func readoutDashesWithoutSample() {
        let rows = ReadoutBuilder.rows(for: unsampled, settings: MetricSettings())
        for id in ["cpu", "ram", "down", "up"] {
            #expect(rows.first { $0.id == id }?.value == "--")
        }
        let live = ReadoutBuilder.rows(for: sampled, settings: MetricSettings())
        #expect(live.first { $0.id == "cpu" }?.value == "42%")
        #expect(live.first { $0.id == "down" }?.value == "2.0 KB/s")
    }

    @Test("the monitor is unsampled until its first refresh, and sampled after it")
    func monitorSampleFlag() {
        let fakes = FakeSources()
        let settings = SettingsViewModel(repository: InMemorySettingsRepository())
        let monitor = MonitorViewModel(
            useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
            settings: settings,
            scheduler: FakeRefreshScheduler()
        )
        #expect(!monitor.snapshot.isSampled)
        #expect(monitor.statusSegments.isEmpty)
        #expect(monitor.itemGlyphs.isEmpty)

        monitor.refresh()
        #expect(monitor.snapshot.isSampled)
    }
}
