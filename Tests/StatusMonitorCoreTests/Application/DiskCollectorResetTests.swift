import Testing
@testable import StatusMonitorCore

@Suite("Disk baseline when the disk collector is disabled")
struct DiskCollectorResetTests {
    @Test("re-enabling the disk collector does not reuse a baseline from before it was disabled")
    func reEnableStartsFresh() {
        let fakes = FakeSources()
        let useCase = SampleSystemMetricsUseCase(sources: fakes.sources)

        useCase.updateConfiguration(filter: .standard, enabled: [.disk])
        fakes.disk.counters = DiskCounters(readBytes: 1_000, writeBytes: 1_000)
        _ = useCase.execute()                       // seeds the baseline

        fakes.clock.advance(seconds: 2)
        fakes.disk.counters = DiskCounters(readBytes: 3_000, writeBytes: 1_000)
        #expect(useCase.execute().disk == DiskRates(readBps: 1_000, writeBps: 0))

        // Collector off for a while. The disk source must not be read at all.
        useCase.updateConfiguration(filter: .standard, enabled: [])
        fakes.clock.advance(seconds: 60)
        fakes.disk.counters = DiskCounters(readBytes: 9_000_000, writeBytes: 1_000)
        _ = useCase.execute()

        // Back on. The old baseline (3_000) must be gone, so this tick only seeds and reports nil.
        useCase.updateConfiguration(filter: .standard, enabled: [.disk])
        fakes.clock.advance(seconds: 2)
        fakes.disk.counters = DiskCounters(readBytes: 100_000, writeBytes: 1_000)
        #expect(useCase.execute().disk == nil)
    }
}
