import Testing
@testable import StatusMonitorCore

@Suite("RAMAlertLevel (colour from the RAM threshold)")
struct RAMAlertLevelTests {
    @Test("below the orange band RAM is normal")
    func normalBelowBand() {
        #expect(RAMAlertLevel.level(usedPercent: 79.9, thresholdPercent: 90) == .normal)
    }

    @Test("orange starts 10 points below the threshold")
    func orangeInBand() {
        #expect(RAMAlertLevel.level(usedPercent: 80, thresholdPercent: 90) == .warning)
        #expect(RAMAlertLevel.level(usedPercent: 89.9, thresholdPercent: 90) == .warning)
    }

    @Test("red at the threshold")
    func redAtThreshold() {
        #expect(RAMAlertLevel.level(usedPercent: 90, thresholdPercent: 90) == .critical)
        #expect(RAMAlertLevel.level(usedPercent: 99, thresholdPercent: 90) == .critical)
    }

    @Test("the threshold is snapped to a slider stop before colouring")
    func snapsThreshold() {
        // 88 snaps to 90, so 80 is the orange start.
        #expect(RAMAlertLevel.level(usedPercent: 80, thresholdPercent: 88) == .warning)
    }

    @Test("unknown total RAM gives no percentage, so no colour is guessed")
    func unknownTotal() {
        #expect(RAMAlertLevel.usedPercent(usedBytes: 1_000, physicalBytes: 0) == nil)
    }

    @Test("used percent is used bytes over physical bytes")
    func usedPercent() {
        #expect(RAMAlertLevel.usedPercent(usedBytes: 4, physicalBytes: 8) == 50)
    }
}
