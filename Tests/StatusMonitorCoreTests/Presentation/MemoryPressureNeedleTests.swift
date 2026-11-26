import Testing
@testable import StatusMonitorCore

@Suite("Memory pressure needle")
struct MemoryPressureNeedleTests {
    @Test("the needle sits low, mid and high for normal, warning and critical")
    func needlePositions() {
        #expect(MemoryPressureNeedle.symbol(for: .normal) == "gauge.with.dots.needle.0percent")
        #expect(MemoryPressureNeedle.symbol(for: .warning) == "gauge.with.dots.needle.50percent")
        #expect(MemoryPressureNeedle.symbol(for: .critical) == "gauge.with.dots.needle.100percent")
    }
}
