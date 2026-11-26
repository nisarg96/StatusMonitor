import Testing
@testable import StatusMonitorCore

@Suite("DiskRateCalculator counter reset")
struct DiskRateResetTests {
    @Test("a decreasing 64-bit counter is a reset: nil for that tick, then the new baseline is used")
    func decreaseIsResetNotWrap() {
        var calc = DiskRateCalculator()
        _ = calc.rates(for: DiskCounters(readBytes: 10_000, writeBytes: 10_000), elapsedSeconds: 0)
        // Counters went backwards (for example, the driver was replaced). Must not report ~2^64 bytes/s.
        #expect(calc.rates(for: DiskCounters(readBytes: 500, writeBytes: 10_500), elapsedSeconds: 2) == nil)
        // The reset tick becomes the baseline, so the next tick measures from 500 / 10_500.
        let next = calc.rates(for: DiskCounters(readBytes: 1_500, writeBytes: 10_500), elapsedSeconds: 2)
        #expect(next == DiskRates(readBps: 500, writeBps: 0))
    }

    @Test("a write counter that decreases alone also resets")
    func writeDecreaseResets() {
        var calc = DiskRateCalculator()
        _ = calc.rates(for: DiskCounters(readBytes: 0, writeBytes: 9_000), elapsedSeconds: 0)
        #expect(calc.rates(for: DiskCounters(readBytes: 100, writeBytes: 1), elapsedSeconds: 1) == nil)
    }
}
