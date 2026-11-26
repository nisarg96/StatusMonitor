import Testing
@testable import StatusMonitorCore

// Times are seconds on a monotonic clock. Each 0.25 s bucket below carries 1,000,000 bytes, which is 32.0 Mbit/s.

@Suite("SpeedTestWindow")
struct SpeedTestWindowTests {
    private func makeWindow(dataCap: Int64 = Int64.max) -> SpeedTestWindow {
        SpeedTestWindow(warmUpCeiling: 3, sampleInterval: 0.25, measuredDuration: 10, dataCap: dataCap)
    }

    @Test("warm-up ends once the last three 250 ms rates are stable")
    func warmUpEndsWhenStable() {
        var window = makeWindow()
        _ = window.update(totalBytes: 0, now: 0)
        #expect(window.phase == .warmUp)

        #expect(window.update(totalBytes: 1_000_000, now: 0.25) == 32.0)
        #expect(window.phase == .warmUp)
        #expect(window.update(totalBytes: 2_000_000, now: 0.5) == 32.0)
        #expect(window.phase == .warmUp)
        #expect(window.update(totalBytes: 3_000_000, now: 0.75) == 32.0)
        #expect(window.phase == .measuring)
    }

    @Test("warm-up ends at the 3 s ceiling when the rates never settle")
    func warmUpEndsAtCeiling() {
        var window = makeWindow()
        _ = window.update(totalBytes: 0, now: 0)
        for bucket in 1...12 {
            let total = Int64(bucket / 2) * 1_000_000
            _ = window.update(totalBytes: total, now: Double(bucket) * 0.25)
            if bucket < 12 {
                #expect(window.phase == .warmUp, "still warming up at \(Double(bucket) * 0.25) s")
            }
        }
        #expect(window.phase == .measuring)
    }

    @Test("bytes received during warm-up are not counted in the window")
    func bytesBeforeWindowIgnored() {
        var window = makeWindow()
        _ = window.update(totalBytes: 0, now: 0)
        _ = window.update(totalBytes: 50_000_000, now: 0.25)
        _ = window.update(totalBytes: 50_000_000, now: 3.0)
        #expect(window.phase == .measuring)

        _ = window.update(totalBytes: 55_000_000, now: 13.0)
        #expect(window.phase == .finished)
        #expect(window.outcome == SpeedTestWindow.Outcome(mbps: 4.0, endedByCap: false))
    }

    @Test("the data cap ends the window early and sets the flag")
    func dataCapEndsWindow() {
        var window = makeWindow(dataCap: 2_000_000)
        _ = window.update(totalBytes: 0, now: 0)
        _ = window.update(totalBytes: 0, now: 3.0)
        #expect(window.phase == .measuring)

        _ = window.update(totalBytes: 1_000_000, now: 3.5)
        #expect(window.phase == .measuring)

        _ = window.update(totalBytes: 2_000_000, now: 4.0)
        #expect(window.phase == .finished)
        #expect(window.outcome == SpeedTestWindow.Outcome(mbps: 16.0, endedByCap: true))
    }

    @Test("the mean covers only the 10 s measured window")
    func meanCoversWindowOnly() {
        var window = makeWindow()
        _ = window.update(totalBytes: 0, now: 0)
        for bucket in 1...43 {
            _ = window.update(totalBytes: Int64(bucket) * 1_000_000, now: Double(bucket) * 0.25)
        }
        #expect(window.phase == .finished)
        #expect(window.outcome == SpeedTestWindow.Outcome(mbps: 32.0, endedByCap: false))
    }
}
