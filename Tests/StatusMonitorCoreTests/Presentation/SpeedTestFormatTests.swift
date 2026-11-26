import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestFormat")
struct SpeedTestFormatTests {
    private let measuredAt = Date(timeIntervalSince1970: 0)

    @Test("a measured rate shows one decimal and the Mbit/s unit")
    func rateText() {
        #expect(SpeedTestFormat.rate(80.04) == "80.0 Mbit/s")
        #expect(SpeedTestFormat.rate(912.26) == "912.3 Mbit/s")
    }

    @Test("a measured zero rate stays zero")
    func measuredZero() {
        #expect(SpeedTestFormat.rate(0) == "0.0 Mbit/s")
        #expect(SpeedTestFormat.milliseconds(0) == "0.0 ms")
    }

    @Test("an unmeasured rate or latency shows a dash, never zero")
    func nilShowsDash() {
        #expect(SpeedTestFormat.rate(nil) == "--")
        #expect(SpeedTestFormat.milliseconds(nil) == "--")
    }

    @Test("a latency shows one decimal and the ms unit")
    func latencyText() {
        #expect(SpeedTestFormat.milliseconds(12.34) == "12.3 ms")
    }

    @Test("rows list download, upload, latency, jitter and packet loss in that order")
    func rowsInOrder() {
        let result = SpeedTestResult(
            downloadMbps: 80.04, uploadMbps: nil, latencyMs: 12.34, jitterMs: nil,
            packetLossPercent: nil, measuredAt: measuredAt
        )
        let rows = SpeedTestFormat.rows(for: result)
        #expect(rows.map(\.label) == ["Download", "Upload", "Latency", "Jitter", "Packet loss"])
        #expect(rows.map(\.value) == ["80.0 Mbit/s", "--", "12.3 ms", "--", "not measured"])
    }

    @Test("a measured packet loss shows a percentage instead of not measured")
    func measuredPacketLoss() {
        let result = SpeedTestResult(packetLossPercent: 0.5, measuredAt: measuredAt)
        #expect(SpeedTestFormat.rows(for: result).last?.value == "0.5%")
    }
}
