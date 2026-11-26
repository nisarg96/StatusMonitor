import Testing
@testable import StatusMonitorCore

@Suite("NetworkRateCalculator")
struct NetworkRateCalculatorTests {
    @Test("first reading only sets a baseline, so rates are zero")
    func firstReadingIsZero() {
        var calc = NetworkRateCalculator()
        let rates = calc.rates(
            for: [.active("en0", rx: 5_000, tx: 1_000)],
            filter: .standard,
            elapsedSeconds: 2
        )
        #expect(rates == .zero)
    }

    @Test("rate is byte delta divided by elapsed seconds")
    func deltaOverElapsed() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 1_000, tx: 100)], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(for: [.active("en0", rx: 3_000, tx: 500)], filter: .standard, elapsedSeconds: 2)
        #expect(rates.downBps == 1_000)   // 2000 bytes / 2 s
        #expect(rates.upBps == 200)       // 400 bytes / 2 s
    }

    @Test("sums across included interfaces")
    func sumsInterfaces() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0"), .active("utun3")], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(
            for: [.active("en0", rx: 100), .active("utun3", rx: 300)],
            filter: .standard,
            elapsedSeconds: 1
        )
        #expect(rates.downBps == 400)
    }

    @Test("excluded interfaces do not contribute")
    func respectsFilter() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.loopback(), .active("en0")], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(
            for: [.loopback(rx: 10_000), .active("en0", rx: 100)],
            filter: .standard,
            elapsedSeconds: 1
        )
        #expect(rates.downBps == 100)
    }

    @Test("32-bit counter rollover is handled")
    func wrapAround() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: UInt32.max - 99)], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(for: [.active("en0", rx: 100)], filter: .standard, elapsedSeconds: 1)
        #expect(rates.downBps == 200)   // 100 bytes to the max, 100 past zero
    }

    @Test("an interface seen for the first time contributes nothing yet")
    func newInterfaceHasNoBaseline() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 0)], filter: .standard, elapsedSeconds: 0)
        let rates = calc.rates(
            for: [.active("en0", rx: 0), .active("en1", rx: 9_999_999)],
            filter: .standard,
            elapsedSeconds: 1
        )
        #expect(rates.downBps == 0)
    }

    @Test("zero elapsed time returns zero but still advances the baseline")
    func zeroElapsedAdvancesBaseline() {
        var calc = NetworkRateCalculator()
        _ = calc.rates(for: [.active("en0", rx: 0)], filter: .standard, elapsedSeconds: 0)
        let zero = calc.rates(for: [.active("en0", rx: 500)], filter: .standard, elapsedSeconds: 0)
        #expect(zero == .zero)
        let next = calc.rates(for: [.active("en0", rx: 1_500)], filter: .standard, elapsedSeconds: 1)
        #expect(next.downBps == 1_000)  // measured from 500, not from 0
    }
}
