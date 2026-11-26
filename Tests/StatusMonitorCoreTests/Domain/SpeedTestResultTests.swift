import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestResult")
struct SpeedTestResultTests {
    @Test("a result with every measurement nil is valid and keeps measuredAt")
    func allNilIsValid() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let result = SpeedTestResult(measuredAt: date)
        #expect(result.downloadMbps == nil)
        #expect(result.uploadMbps == nil)
        #expect(result.latencyMs == nil)
        #expect(result.jitterMs == nil)
        #expect(result.packetLossPercent == nil)
        #expect(result.measuredAt == date)
    }

    @Test("an unmeasured field stays nil and never becomes 0")
    func nilNeverBecomesZero() {
        let result = SpeedTestResult(downloadMbps: 80.0, measuredAt: Date(timeIntervalSince1970: 0))
        #expect(result.uploadMbps == nil)
        #expect(result.uploadMbps != 0)
        #expect(result.downloadMbps == 80.0)
    }
}
