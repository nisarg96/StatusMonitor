import Testing
@testable import StatusMonitorCore

@Suite("Status segments carry an icon and a value")
struct SegmentSymbolTests {
    private let snapshot = SystemSnapshot(
        cpuPercent: 42, memoryUsedBytes: 3_435_973_837, downBps: 1_000, upBps: 2_000
    )

    @Test("each metric segment has its own symbol and a separate value")
    func symbolAndValue() {
        // Default bar: CPU, RAM, then network (GPU and the other items are absent from this snapshot or hidden).
        let segments = StatusTitleFormatter.segments(for: snapshot, settings: MetricSettings(showNetwork: true))
        #expect(segments.count == 3)
        #expect(segments[0] == TitleSegment(symbol: MetricSymbol.cpu, plainLabel: "CPU", value: "42%"))
        #expect(segments[1].symbol == MetricSymbol.memory)
        #expect(segments[2].symbol == MetricSymbol.network)
        #expect(segments[2].value == "↓ 1000 B/s ↑ 2.0 KB/s")
    }

    @Test("plain text is still label plus value, so the CLI output is unchanged")
    func plainText() {
        let segment = TitleSegment(symbol: MetricSymbol.cpu, plainLabel: "CPU", value: "42%")
        #expect(segment.plainText == "CPU 42%")
    }

    @Test("a segment without a label shows only its value")
    func unlabelled() {
        let segment = TitleSegment(symbol: MetricSymbol.thermal, plainLabel: "", value: "54 °C")
        #expect(segment.plainText == "54 °C")
    }

    @Test("battery icon follows the charge level, and charging uses the bolt")
    func batteryIcons() {
        #expect(MetricSymbol.battery(percent: 5, charging: false) == "battery.0")
        #expect(MetricSymbol.battery(percent: 30, charging: false) == "battery.25")
        #expect(MetricSymbol.battery(percent: 50, charging: false) == "battery.50")
        #expect(MetricSymbol.battery(percent: 80, charging: false) == "battery.75")
        #expect(MetricSymbol.battery(percent: 100, charging: false) == "battery.100")
        #expect(MetricSymbol.battery(percent: 40, charging: true) == "battery.100.bolt")
    }

    @Test("popover rows carry their metric's symbol")
    func rowSymbols() {
        let rows = ReadoutBuilder.rows(for: snapshot, settings: MetricSettings(showNetwork: false))
        #expect(rows.first { $0.id == "cpu" }?.symbol == MetricSymbol.cpu)
        #expect(rows.first { $0.id == "ram" }?.symbol == MetricSymbol.memory)
    }
}
