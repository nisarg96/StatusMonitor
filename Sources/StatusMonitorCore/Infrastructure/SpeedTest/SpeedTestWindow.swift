import Foundation

/**
 Decides when one speed test phase leaves warm-up, and when its measured window ends.

 Warm-up ends once the 250 ms rates are stable, or at the warm-up ceiling. The measured window then runs for its
 duration, and only bytes received inside it count toward the mean. The data cap is checked against those same
 window bytes, so it ends the window early and sets `Outcome.endedByCap`.

 Times are seconds on a monotonic clock. Byte totals are cumulative counts for the phase.
 */
struct SpeedTestWindow {
    /// Where the phase is in its life cycle.
    enum Phase: Equatable {
        /// `update` has not been called yet, so the phase has no start time.
        case notStarted
        /// Rates are sampled until they settle or the ceiling passes.
        case warmUp
        /// Bytes count toward the mean until the window ends.
        case measuring
        /// The window has ended, and `outcome` is set.
        case finished
    }

    /// The result of a finished phase.
    struct Outcome: Equatable {
        /// The mean rate over the measured window, in decimal Mbit/s. Nil when the window had no measurable length.
        let mbps: Double?
        /// True when the data cap ended the window before its duration passed.
        let endedByCap: Bool
    }

    private let warmUpCeiling: Double
    private let sampleInterval: Double
    private let measuredDuration: Double
    private let dataCap: Int64

    /// The current life-cycle phase.
    private(set) var phase: Phase = .notStarted
    /// The result, set once the phase has finished.
    private(set) var outcome: Outcome?

    private var phaseStart: Double = 0
    private var sampleStart: Double = 0
    private var sampleStartTotal: Int64 = 0
    private var rates: [Double] = []
    private var measureStart: Double = 0
    private var measureBaseline: Int64 = 0

    /**
     Creates a window for one phase.

     - Parameters:
       - warmUpCeiling: Seconds after which warm-up ends even if the rates are not stable.
       - sampleInterval: Seconds per rate sample. The spec uses 0.25.
       - measuredDuration: Seconds the measured window lasts after warm-up.
       - dataCap: Bytes counted inside the measured window that end it early.
     */
    init(warmUpCeiling: Double, sampleInterval: Double, measuredDuration: Double, dataCap: Int64) {
        self.warmUpCeiling = warmUpCeiling
        self.sampleInterval = sampleInterval
        self.measuredDuration = measuredDuration
        self.dataCap = dataCap
    }

    /**
     Feeds the latest cumulative byte count and advances the phase.

     - Parameters:
       - totalBytes: Bytes counted since the phase began, across all streams.
       - now: The current monotonic time in seconds.
     - Returns: The rate of a sample that closed on this call, in decimal Mbit/s, or nil when none closed.
     */
    mutating func update(totalBytes: Int64, now: Double) -> Double? {
        switch phase {
        case .notStarted:
            phase = .warmUp
            phaseStart = now
            sampleStart = now
            sampleStartTotal = totalBytes
            return nil
        case .warmUp:
            let rate = closeSampleIfDue(totalBytes: totalBytes, now: now)
            if let rate {
                rates.append(rate)
            }
            if SpeedTestMath.isStable(rates) || now - phaseStart >= warmUpCeiling {
                phase = .measuring
                measureStart = now
                measureBaseline = totalBytes
            }
            return rate
        case .measuring:
            let rate = closeSampleIfDue(totalBytes: totalBytes, now: now)
            let windowBytes = totalBytes - measureBaseline
            if windowBytes >= dataCap {
                finish(windowBytes: windowBytes, now: now, endedByCap: true)
            } else if now - measureStart >= measuredDuration {
                finish(windowBytes: windowBytes, now: now, endedByCap: false)
            }
            return rate
        case .finished:
            return nil
        }
    }

    private mutating func closeSampleIfDue(totalBytes: Int64, now: Double) -> Double? {
        let elapsed = now - sampleStart
        guard elapsed >= sampleInterval else { return nil }
        let rate = SpeedTestMath.mbps(bytes: totalBytes - sampleStartTotal, seconds: elapsed)
        sampleStart = now
        sampleStartTotal = totalBytes
        return rate
    }

    private mutating func finish(windowBytes: Int64, now: Double, endedByCap: Bool) {
        let mean = SpeedTestMath.windowMean(bytesReceived: windowBytes, windowSeconds: now - measureStart)
        outcome = Outcome(mbps: mean, endedByCap: endedByCap)
        phase = .finished
    }
}
