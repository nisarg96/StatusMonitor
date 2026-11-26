import Testing
@testable import StatusMonitorCore

@Suite("NetworkRateCalculator backwards counters")
struct NetworkBackwardsCounterTests {
    @Test("a counter that goes backwards is a reset and contributes nothing")
    func backwardsIsReset() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 5_000, tx: 5_000)], filter: .standard, elapsedSeconds: 0)
        // 5_000 -> 1_000 is a 32-bit delta of about 4 GB, not a wrap. It must not be reported as a rate.
        let rates = calc.rates(for: [.active("en0", rx: 1_000, tx: 1_000)], filter: .standard, elapsedSeconds: 2)
        #expect(rates == .zero)
        // The reset value is the new baseline.
        let next = calc.rates(for: [.active("en0", rx: 3_000, tx: 1_000)], filter: .standard, elapsedSeconds: 2)
        #expect(next.downBps == 1_000)
    }

    @Test("a forward delta above 2^31 bytes is treated as a reset")
    func hugeForwardDeltaIsReset() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 0, tx: 0)], filter: .standard, elapsedSeconds: 0)
        // 3 GB in one tick is implausible for a 2 s cadence, so it is a reset (0), not a rate.
        let rates = calc.rates(for: [.active("en0", rx: 3_000_000_000, tx: 0)], filter: .standard, elapsedSeconds: 2)
        #expect(rates.downBps == 0)
    }

    @Test("a wrap whose delta is below 2^31 still counts")
    func smallWrapStillCounts() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: UInt32.max - 99)], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(for: [.active("en0", rx: 100)], filter: .standard, elapsedSeconds: 1)
        #expect(rates.downBps == 200)
    }

    @Test("a delta above the plausible maximum for a short elapsed time is a reset")
    func implausibleForShortInterval() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 0)], filter: .standard, elapsedSeconds: 0)
        // 500 MB in 0.1 s is far above any plausible rate, so it is a reset.
        let rates = calc.rates(for: [.active("en0", rx: 500_000_000)], filter: .standard, elapsedSeconds: 0.1)
        #expect(rates.downBps == 0)
    }
}
