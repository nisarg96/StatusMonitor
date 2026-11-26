import Testing
@testable import StatusMonitorCore

// Speed test results use decimal Mbit/s (1 Mbit = 10^6 bits). This differs from the 1024-step rates used elsewhere.

@Suite("SpeedTestMath")
struct SpeedTestMathTests {
    @Test("uses decimal units: 10,000,000 bytes in exactly 1 s is 80.0 Mbit/s")
    func decimalUnits() {
        #expect(SpeedTestMath.mbps(bytes: 10_000_000, seconds: 1) == 80.0)
    }

    @Test("zero seconds gives nil")
    func mbpsZeroSeconds() {
        #expect(SpeedTestMath.mbps(bytes: 10_000_000, seconds: 0) == nil)
    }

    @Test("negative bytes give nil")
    func mbpsNegativeBytes() {
        #expect(SpeedTestMath.mbps(bytes: -1, seconds: 1) == nil)
    }

    @Test("zero bytes is a measured 0 Mbit/s, not nil")
    func mbpsZeroBytes() {
        #expect(SpeedTestMath.mbps(bytes: 0, seconds: 2) == 0.0)
    }

    @Test("windowMean matches mbps for the same bytes and window")
    func windowMeanMatchesMbps() {
        #expect(SpeedTestMath.windowMean(bytesReceived: 10_000_000, windowSeconds: 1) == 80.0)
        #expect(SpeedTestMath.windowMean(bytesReceived: 10_000_000, windowSeconds: 0) == nil)
    }

    @Test("median of an empty array is nil")
    func medianEmpty() {
        #expect(SpeedTestMath.median([]) == nil)
    }

    @Test("median of an odd count is the middle value")
    func medianOdd() {
        #expect(SpeedTestMath.median([9, 1, 5]) == 5)
    }

    @Test("median of an even count is the mean of the two middle values")
    func medianEven() {
        #expect(SpeedTestMath.median([4, 1, 3, 2]) == 2.5)
    }

    @Test("median does not change the input array")
    func medianKeepsInput() {
        let input = [5.0, 1.0, 3.0]
        _ = SpeedTestMath.median(input)
        #expect(input == [5.0, 1.0, 3.0])
    }

    @Test("jitter with fewer than 2 samples is nil")
    func jitterTooFew() {
        #expect(SpeedTestMath.jitter([]) == nil)
        #expect(SpeedTestMath.jitter([10]) == nil)
    }

    @Test("jitter of [10, 20, 10] is 10.0")
    func jitterThreeSamples() {
        #expect(SpeedTestMath.jitter([10, 20, 10]) == 10.0)
    }

    @Test("jitter of two samples is the same in either order")
    func jitterTwoSamplesOrderIndependent() {
        #expect(SpeedTestMath.jitter([10, 20]) == 10.0)
        #expect(SpeedTestMath.jitter([20, 10]) == 10.0)
    }

    @Test("jitter depends on the order of the samples")
    func jitterOrderMatters() {
        #expect(SpeedTestMath.jitter([10, 30, 20]) == 15.0)
    }

    @Test("latency subtracts server timing from the round trip")
    func latencySubtractsServerTiming() {
        #expect(SpeedTestMath.latencyFromServerTiming(roundTripMs: 100, serverTimingMs: 40) == 60)
    }

    @Test("latency clamps at 0 when server timing exceeds the round trip")
    func latencyClampsAtZero() {
        #expect(SpeedTestMath.latencyFromServerTiming(roundTripMs: 30, serverTimingMs: 50) == 0)
    }

    @Test("latency with no server timing returns the round trip")
    func latencyWithoutServerTiming() {
        #expect(SpeedTestMath.latencyFromServerTiming(roundTripMs: 72.5, serverTimingMs: nil) == 72.5)
    }

    @Test("stability with fewer than 3 values is false")
    func stabilityTooFew() {
        #expect(SpeedTestMath.isStable([]) == false)
        #expect(SpeedTestMath.isStable([100, 100]) == false)
    }

    @Test("three equal values are stable")
    func stabilityEqualValues() {
        #expect(SpeedTestMath.isStable([100, 100, 100]) == true)
    }

    @Test("only the last three values are checked")
    func stabilityUsesLastThree() {
        #expect(SpeedTestMath.isStable([1_000, 100, 100, 100]) == true)
    }

    @Test("a value 20% off the mean is not stable")
    func stabilityTwentyPercentOff() {
        #expect(SpeedTestMath.isStable([80, 100, 120]) == false)
    }

    @Test("packet loss with 0 sent is nil")
    func packetLossZeroSent() {
        #expect(SpeedTestMath.packetLossPercent(sent: 0, received: 0) == nil)
    }

    @Test("packet loss of 9 received out of 10 sent is 10.0%")
    func packetLossOneInTen() {
        #expect(SpeedTestMath.packetLossPercent(sent: 10, received: 9) == 10.0)
    }

    @Test("packet loss with more received than sent is nil")
    func packetLossReceivedExceedsSent() {
        #expect(SpeedTestMath.packetLossPercent(sent: 10, received: 11) == nil)
    }
}
