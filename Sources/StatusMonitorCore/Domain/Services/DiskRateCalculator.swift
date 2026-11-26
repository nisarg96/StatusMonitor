import Foundation

/**
 Turns cumulative disk byte counters into per-second throughput.

 The first reading after a gap only seeds the baseline, so it returns nil instead of a fake zero.
 */
public struct DiskRateCalculator: Sendable {
    private var baseline: DiskCounters?

    /// Creates a calculator with no baseline.
    public init() {}

    /**
     Returns the throughput since the previous reading.

     Each call makes `current` the new baseline, unless `current` is nil. A nil reading drops the baseline, so the first
     reading after the gap seeds a new one instead of averaging across the gap.

     A counter that went backwards also returns nil. The counters are 64-bit and do not wrap in practice, so a decrease
     means they were reset. This intentionally departs from the wrapping-subtraction rule used for the 32-bit counters:
     a wrapped difference would report a near-2^64 byte rate. The reset reading becomes the new baseline.

     - Parameters:
       - current: The counters read this tick, or nil when they could not be read.
       - elapsedSeconds: The measured seconds since the previous reading. A value of 0 or less returns nil.
     - Returns: The read and write rates in bytes per second, or nil when there is no baseline, the elapsed time is not
       positive, or a counter went backwards.
     */
    public mutating func rates(for current: DiskCounters?, elapsedSeconds: Double) -> DiskRates? {
        guard let current else {
            baseline = nil
            return nil
        }
        defer { baseline = current }
        guard let previous = baseline, elapsedSeconds > 0 else { return nil }
        guard current.readBytes >= previous.readBytes, current.writeBytes >= previous.writeBytes else {
            return nil
        }

        return DiskRates(
            readBps: Double(current.readBytes - previous.readBytes) / elapsedSeconds,
            writeBps: Double(current.writeBytes - previous.writeBytes) / elapsedSeconds
        )
    }
}
