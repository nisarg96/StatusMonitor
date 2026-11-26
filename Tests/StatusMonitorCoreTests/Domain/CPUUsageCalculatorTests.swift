import Testing
@testable import StatusMonitorCore

@Suite("CPUUsageCalculator")
struct CPUUsageCalculatorTests {
    @Test("busy share of the tick delta")
    func busyShareOfDelta() {
        let previous = CPUTicks(user: 10, system: 0, idle: 90, nice: 0)
        let current = CPUTicks(user: 20, system: 0, idle: 170, nice: 0)
        // busy delta 10, idle delta 80 => 10 / 90
        #expect(abs(CPUUsageCalculator.usage(previous: previous, current: current) - 11.111) < 0.01)
    }

    @Test("system and nice ticks count as busy")
    func systemAndNiceAreBusy() {
        let previous = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTicks(user: 10, system: 10, idle: 20, nice: 10)
        // busy 30, idle 20 => 60%
        #expect(CPUUsageCalculator.usage(previous: previous, current: current) == 60)
    }

    @Test("handles 32-bit counter rollover")
    func wrapAround() {
        let previous = CPUTicks(user: UInt32.max - 5, system: 0, idle: UInt32.max - 5, nice: 0)
        let current = CPUTicks(user: 5, system: 0, idle: 5, nice: 0)
        // busy delta 11, idle delta 11 => 50%
        #expect(CPUUsageCalculator.usage(previous: previous, current: current) == 50)
    }

    @Test("no elapsed ticks reports zero")
    func noElapsedTicks() {
        let same = CPUTicks(user: 7, system: 7, idle: 7, nice: 7)
        #expect(CPUUsageCalculator.usage(previous: same, current: same) == 0)
    }
}
