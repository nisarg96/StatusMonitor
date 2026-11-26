import Foundation

/// Bytes per second for the download and upload directions.
public struct ThroughputRates: Equatable, Sendable {
    public var downBps: Double
    public var upBps: Double

    public init(downBps: Double, upBps: Double) {
        self.downBps = downBps
        self.upBps = upBps
    }

    public static let zero = ThroughputRates(downBps: 0, upBps: 0)
}

/// Turns successive interface counter readings into throughput.
/// Stateful only through its baseline: the last counters seen for each interface.
public struct NetworkRateCalculator: Sendable {
    private struct Baseline: Equatable, Sendable {
        var rx: UInt32
        var tx: UInt32
    }

    private var baselines: [String: Baseline] = [:]

    public init() {}

    /// Sums per-interface deltas over the included interfaces and divides by the real elapsed time.
    /// - An interface with no earlier baseline contributes 0 (it may have just appeared).
    /// - Counters are 32-bit; wrapping subtraction handles rollover.
    /// - The baseline always advances, even when `elapsedSeconds` is 0, so the next call measures correctly.
    public mutating func rates(
        for interfaces: [InterfaceCounters],
        filter: InterfaceFilter,
        elapsedSeconds: Double
    ) -> ThroughputRates {
        var rxDelta: UInt64 = 0
        var txDelta: UInt64 = 0
        var next: [String: Baseline] = [:]

        for interface in interfaces where filter.includes(interface) {
            next[interface.name] = Baseline(rx: interface.rxBytes, tx: interface.txBytes)
            if let previous = baselines[interface.name] {
                rxDelta += UInt64(interface.rxBytes &- previous.rx)
                txDelta += UInt64(interface.txBytes &- previous.tx)
            }
        }
        baselines = next

        guard elapsedSeconds > 0 else { return .zero }
        return ThroughputRates(
            downBps: Double(rxDelta) / elapsedSeconds,
            upBps: Double(txDelta) / elapsedSeconds
        )
    }
}
