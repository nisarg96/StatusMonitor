import Foundation

/// Bytes per second for the download and upload directions, plus the bytes that moved in the measured window.
public struct ThroughputRates: Equatable, Sendable {
    /// Bytes per second received.
    public var downBps: Double
    /// Bytes per second sent.
    public var upBps: Double
    /// Bytes received since the previous reading. Totals should add these, not rate times interval.
    public var downBytes: UInt64
    /// Bytes sent since the previous reading. Totals should add these, not rate times interval.
    public var upBytes: UInt64

    /**
     Creates throughput rates.

     - Parameters:
       - downBps: Bytes per second received.
       - upBps: Bytes per second sent.
       - downBytes: Bytes received in the measured window. Defaults to 0.
       - upBytes: Bytes sent in the measured window. Defaults to 0.
     */
    public init(downBps: Double, upBps: Double, downBytes: UInt64 = 0, upBytes: UInt64 = 0) {
        self.downBps = downBps
        self.upBps = upBps
        self.downBytes = downBytes
        self.upBytes = upBytes
    }

    /// No traffic in either direction.
    public static let zero = ThroughputRates(downBps: 0, upBps: 0)
}

/**
 Turns successive interface counter readings into throughput.

 Stateful only through its baseline: the last counters seen for each interface.
 */
public struct NetworkRateCalculator: Sendable {
    private struct Baseline: Equatable, Sendable {
        var receivedBytes: UInt32
        var transmittedBytes: UInt32
    }

    private var baselines: [String: Baseline] = [:]

    /// A forward delta above 2^31 bytes is not a wrap, so it is treated as a reset.
    private static let maxCountedDelta: UInt32 = 1 << 31
    /**
     The upper bound on a plausible rate, in bytes per second (2 GiB/s).

     A delta above this times the elapsed seconds is treated as a reset.
     */
    private static let maxPlausibleBytesPerSecond: Double = 2_147_483_648

    /// Creates a calculator with no baselines.
    public init() {}

    /**
     Returns the bytes one interface moved since its last reading.

     Subtraction wraps at 32 bits, so a genuine rollover (a small delta across zero) still counts. A counter that went
     backwards wraps to a delta near 2^32, and an implausibly large jump is also a reset.

     - Parameters:
       - current: The counter read this tick.
       - previous: The counter from the previous reading.
       - elapsedSeconds: The measured seconds since the previous reading.
     - Returns: The bytes moved, or 0 when the delta is a reset.
     */
    private static func countedDelta(current: UInt32, previous: UInt32, elapsedSeconds: Double) -> UInt64 {
        let delta = current &- previous
        guard delta <= maxCountedDelta else { return 0 }
        guard Double(delta) <= maxPlausibleBytesPerSecond * elapsedSeconds else { return 0 }
        return UInt64(delta)
    }

    /**
     Sums per-interface deltas over the included interfaces and divides by the real elapsed time.

     - An interface with no earlier baseline contributes 0, because it may have just appeared.
     - Counters are 32-bit. A small delta across zero is a rollover and counts. A backwards counter, or a delta above
       2^31 bytes or above the plausible maximum for the elapsed time, is a reset and contributes 0.
     - The baseline always advances, even when `elapsedSeconds` is 0, so the next call measures correctly.

     - Parameters:
       - interfaces: The counters read this tick, one record per interface.
       - filter: The policy that decides which interfaces count.
       - elapsedSeconds: The real seconds since the previous call, measured on the monotonic clock.
     - Returns: The download and upload rates in bytes per second, and the bytes moved in the window. The result is
       `.zero` when `elapsedSeconds` is 0 or less.
     */
    public mutating func rates(
        for interfaces: [InterfaceCounters],
        filter: InterfaceFilter,
        elapsedSeconds: Double
    ) -> ThroughputRates {
        var rxDelta: UInt64 = 0
        var txDelta: UInt64 = 0
        var next: [String: Baseline] = [:]

        for interface in interfaces where filter.includes(interface) {
            next[interface.name] = Baseline(receivedBytes: interface.rxBytes, transmittedBytes: interface.txBytes)
            if let previous = baselines[interface.name] {
                rxDelta += Self.countedDelta(
                    current: interface.rxBytes, previous: previous.receivedBytes, elapsedSeconds: elapsedSeconds)
                txDelta += Self.countedDelta(
                    current: interface.txBytes, previous: previous.transmittedBytes, elapsedSeconds: elapsedSeconds)
            }
        }
        baselines = next

        guard elapsedSeconds > 0 else { return .zero }
        return ThroughputRates(
            downBps: Double(rxDelta) / elapsedSeconds,
            upBps: Double(txDelta) / elapsedSeconds,
            downBytes: rxDelta,
            upBytes: txDelta
        )
    }
}
