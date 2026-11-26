import Testing
@testable import StatusMonitorCore

@Suite("MemoryCleanSummary")
struct MemoryCleanSummaryTests {
    private let gib: UInt64 = 1_073_741_824

    @Test("free memory at the threshold is physical × (100 − pct) / 100 in GiB")
    func freeGiB() {
        #expect(MemoryCleanSummary.freeGiB(thresholdPercent: 85, physicalBytes: 16 * gib) == 2.4)
        #expect(MemoryCleanSummary.freeGiB(thresholdPercent: 100, physicalBytes: 16 * gib) == 0)
        #expect(MemoryCleanSummary.freeGiB(thresholdPercent: 70, physicalBytes: 8 * gib) == 2.4)
    }

    @Test("the threshold is snapped to a slider stop before the arithmetic")
    func snapsThreshold() {
        #expect(MemoryCleanSummary.freeGiB(thresholdPercent: 84, physicalBytes: 16 * gib)
            == MemoryCleanSummary.freeGiB(thresholdPercent: 85, physicalBytes: 16 * gib))
        #expect(MemoryCleanSummary.freeGiB(thresholdPercent: 50, physicalBytes: 16 * gib)
            == MemoryCleanSummary.freeGiB(thresholdPercent: 70, physicalBytes: 16 * gib))
    }

    @Test("the sentence shows the snapped percentage, free GB and total GB, one decimal")
    func sentence() {
        #expect(MemoryCleanSummary.sentence(thresholdPercent: 85, physicalBytes: 16 * gib)
            == "Clean when RAM in use reaches 85%, about 2.4 GB free of 16.0 GB.")
    }

    @Test("the cooldown text comes from the policy, not a typed constant")
    func cooldownText() {
        #expect(MemoryCleanSummary.cooldownText == "3 minutes")
    }
}
