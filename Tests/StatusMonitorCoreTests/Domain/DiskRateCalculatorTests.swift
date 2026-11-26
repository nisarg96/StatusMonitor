import Testing
@testable import StatusMonitorCore

@Suite("DiskRateCalculator")
struct DiskRateCalculatorTests {
    @Test("the first reading only seeds a baseline and returns nil")
    func firstReadingIsNil() {
        var calc = DiskRateCalculator()
        #expect(calc.rates(for: DiskCounters(readBytes: 10, writeBytes: 10), elapsedSeconds: 2) == nil)
    }

    @Test("rates are byte deltas over elapsed seconds")
    func deltas() {
        var calc = DiskRateCalculator()
        _ = calc.rates(for: DiskCounters(readBytes: 0, writeBytes: 0), elapsedSeconds: 0)
        let rates = calc.rates(for: DiskCounters(readBytes: 2_000, writeBytes: 600), elapsedSeconds: 2)
        #expect(rates == DiskRates(readBps: 1_000, writeBps: 300))
    }

    @Test("a dropped reading clears the baseline so the gap is not averaged in")
    func gapResetsBaseline() {
        var calc = DiskRateCalculator()
        _ = calc.rates(for: DiskCounters(readBytes: 0, writeBytes: 0), elapsedSeconds: 0)
        #expect(calc.rates(for: nil, elapsedSeconds: 2) == nil)
        // The first reading after the gap re-seeds, so it is nil rather than a rate across the gap.
        #expect(calc.rates(for: DiskCounters(readBytes: 9_999, writeBytes: 0), elapsedSeconds: 2) == nil)
    }

    @Test("zero elapsed time yields nil instead of infinity")
    func zeroElapsed() {
        var calc = DiskRateCalculator()
        _ = calc.rates(for: DiskCounters(readBytes: 0, writeBytes: 0), elapsedSeconds: 0)
        #expect(calc.rates(for: DiskCounters(readBytes: 100, writeBytes: 0), elapsedSeconds: 0) == nil)
    }
}
