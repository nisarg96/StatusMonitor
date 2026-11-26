import Testing
@testable import StatusMonitorCore

@Suite("ChartTooltipText")
struct ChartTooltipTextTests {
    @Test("network tooltip shows upload then download, using the rate format")
    func network() {
        let parts = ChartTooltipText.network(upBps: 1.2 * 1024 * 1024, downBps: 340 * 1024)
        #expect(parts == ["↑ 1.2 MB/s", "↓ 340.0 KB/s"])
    }

    @Test("disk tooltip shows read then write")
    func disk() {
        #expect(ChartTooltipText.disk(readBps: 2048, writeBps: 0) == ["↓ 2.0 KB/s", "↑ 0 B/s"])
    }

    @Test("CPU tooltip shows the whole percent")
    func cpu() {
        #expect(ChartTooltipText.cpu(percent: 12.4) == ["CPU 12%"])
    }
}
