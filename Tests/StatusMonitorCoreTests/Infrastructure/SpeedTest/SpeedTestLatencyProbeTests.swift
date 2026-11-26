import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestLatencyProbe")
struct SpeedTestLatencyProbeTests {
    private typealias Observation = SpeedTestLatencyProbe.Observation

    @Test("only reused connections are kept")
    func onlyReusedConnectionsKept() {
        let observations = [
            Observation(roundTripMs: 10, serverTimingMs: nil, isReusedConnection: true),
            Observation(roundTripMs: 50, serverTimingMs: nil, isReusedConnection: false),
            Observation(roundTripMs: 20, serverTimingMs: nil, isReusedConnection: true),
            Observation(roundTripMs: 1000, serverTimingMs: nil, isReusedConnection: false),
            Observation(roundTripMs: 40, serverTimingMs: nil, isReusedConnection: true)
        ]
        let measurement = SpeedTestLatencyProbe.summarize(observations)
        #expect(measurement?.medianMs == 20)
    }

    @Test("median and jitter come from the kept samples, in send order")
    func medianAndJitterFromKeptSamples() {
        let observations = [
            Observation(roundTripMs: 40, serverTimingMs: nil, isReusedConnection: true),
            Observation(roundTripMs: 500, serverTimingMs: nil, isReusedConnection: false),
            Observation(roundTripMs: 10, serverTimingMs: nil, isReusedConnection: true),
            Observation(roundTripMs: 20, serverTimingMs: nil, isReusedConnection: true)
        ]
        let measurement = SpeedTestLatencyProbe.summarize(observations)
        #expect(measurement?.medianMs == 20)
        #expect(measurement?.jitterMs == 20)
    }

    @Test("server timing is subtracted from the round trip")
    func serverTimingSubtracted() {
        let observations = [Observation(roundTripMs: 30, serverTimingMs: 10, isReusedConnection: true)]
        #expect(SpeedTestLatencyProbe.summarize(observations)?.medianMs == 20)
    }

    @Test("server timing larger than the round trip clamps the latency at zero")
    func serverTimingClamped() {
        let observations = [Observation(roundTripMs: 5, serverTimingMs: 9, isReusedConnection: true)]
        #expect(SpeedTestLatencyProbe.summarize(observations)?.medianMs == 0)
    }

    @Test("no reused connection gives no measurement")
    func noReusedConnections() {
        let observations = [Observation(roundTripMs: 10, serverTimingMs: nil, isReusedConnection: false)]
        #expect(SpeedTestLatencyProbe.summarize(observations) == nil)
    }

    @Test("the Server-Timing header yields the cfRequestDuration value")
    func serverTimingHeaderParsed() {
        let header = "cfL4;desc=\"?proto=TCP&rtt=12\", cfRequestDuration;dur=12.5"
        #expect(SpeedTestLatencyProbe.serverTimingMs(fromHeader: header) == 12.5)
        #expect(SpeedTestLatencyProbe.serverTimingMs(fromHeader: "cfL4;desc=\"x\"") == nil)
        #expect(SpeedTestLatencyProbe.serverTimingMs(fromHeader: nil) == nil)
    }
}
