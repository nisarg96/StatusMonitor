import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("TimedSampleHistory")
struct TimedSampleHistoryTests {
    @Test("each value keeps the time it was recorded at")
    func keepsTimes() {
        var history = TimedSampleHistory()
        history.append(1.5, at: Date(timeIntervalSince1970: 10))
        history.append(2.5, at: Date(timeIntervalSince1970: 20))
        #expect(history.values == [1.5, 2.5])
        #expect(history.times == [Date(timeIntervalSince1970: 10), Date(timeIntervalSince1970: 20)])
    }

    @Test("history is capped at the shared capacity, dropping the oldest sample")
    func capped() {
        var history = TimedSampleHistory()
        for index in 0..<(SampleHistory.capacity + 5) {
            history.append(Double(index), at: Date(timeIntervalSince1970: Double(index)))
        }
        #expect(history.samples.count == SampleHistory.capacity)
        #expect(history.values.first == 5)
        #expect(history.times.first == Date(timeIntervalSince1970: 5))
        #expect(history.times.count == history.values.count)
    }
}
