import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("ChartHover")
struct ChartHoverTests {
    private let utc = TimeZone(identifier: "UTC")!

    /// Samples two seconds apart, starting at the Unix epoch.
    private func evenTimes(_ count: Int) -> [Date] {
        (0..<count).map { Date(timeIntervalSince1970: Double($0) * 2) }
    }

    @Test("empty history gives no hover result")
    func emptyHistory() {
        #expect(ChartHover.index(atX: 50, width: 100, times: []) == nil)
        let readout = ChartHover.readout(atX: 50, width: 100, times: [], timeZone: utc) { _ in ["x"] }
        #expect(readout == nil)
    }

    @Test("one sample is always the hover result, at any x")
    func oneSample() {
        let times = evenTimes(1)
        for position in [-10.0, 0, 50, 100, 150] {
            #expect(ChartHover.index(atX: position, width: 100, times: times) == 0)
        }
    }

    @Test("pointer at the left edge selects the oldest sample")
    func leftEdge() {
        #expect(ChartHover.index(atX: 0, width: 100, times: evenTimes(5)) == 0)
    }

    @Test("pointer at the right edge selects the newest sample")
    func rightEdge() {
        #expect(ChartHover.index(atX: 100, width: 100, times: evenTimes(5)) == 4)
    }

    @Test("pointer beyond either edge is clamped to the first or last sample")
    func beyondEdgesClamped() {
        let times = evenTimes(5)
        #expect(ChartHover.index(atX: -40, width: 100, times: times) == 0)
        #expect(ChartHover.index(atX: 140, width: 100, times: times) == 4)
    }

    @Test("nearest sample is chosen by time, so a gap after sleep is respected")
    func sleepGap() {
        // Samples at 0, 2, 4 s, then a 10-minute gap, then 602 s. Index-based mapping would pick index 4 at x = 90.
        let times = [0.0, 2, 4, 600, 602].map { Date(timeIntervalSince1970: $0) }
        #expect(ChartHover.index(atX: 90, width: 100, times: times) == 3)
        // x = 10 is 60.2 s into the 602 s span, nearest to the sample at 4 s (index 2), not the one after the gap.
        #expect(ChartHover.index(atX: 10, width: 100, times: times) == 2)
    }

    @Test("zero width gives no hover result")
    func zeroWidth() {
        #expect(ChartHover.index(atX: 0, width: 0, times: evenTimes(3)) == nil)
    }

    @Test("readout gives the sample's time, formatted as HH:mm:ss")
    func readoutTime() {
        // 53 min 12 s after the epoch, in UTC.
        let times = [Date(timeIntervalSince1970: 3192)]
        let readout = ChartHover.readout(atX: 0, width: 100, times: times, timeZone: utc) { _ in [] }
        #expect(readout?.timeText == "00:53:12")
        #expect(readout?.index == 0)
    }

    @Test("readout joins the value parts for the chosen sample")
    func readoutValues() {
        let times = evenTimes(3)
        let readout = ChartHover.readout(atX: 100, width: 100, times: times, timeZone: utc) { index in
            ["↑ \(index)", "↓ \(index * 10)"]
        }
        #expect(readout?.index == 2)
        #expect(readout?.valueText == "↑ 2, ↓ 20")
    }

    @Test("x position of a sample is proportional to its time, and clamps to the width")
    func xPosition() {
        let times = [0.0, 2, 4, 600, 602].map { Date(timeIntervalSince1970: $0) }
        #expect(ChartHover.xPosition(forTime: times[0], width: 100, times: times) == 0)
        #expect(ChartHover.xPosition(forTime: times[4], width: 100, times: times) == 100)
        let gapEnd = ChartHover.xPosition(forTime: times[3], width: 100, times: times) ?? -1
        #expect(abs(gapEnd - 600.0 / 602.0 * 100) < 0.001)
    }

    @Test("y position maps the domain to the height, top to bottom")
    func yPosition() {
        #expect(ChartHover.yPosition(value: 100, domain: 0...100, height: 34) == 0)
        #expect(ChartHover.yPosition(value: 0, domain: 0...100, height: 34) == 34)
        #expect(ChartHover.yPosition(value: 50, domain: 0...100, height: 34) == 17)
        #expect(ChartHover.yPosition(value: 5, domain: 3...3, height: 34) == 17)
    }
}
