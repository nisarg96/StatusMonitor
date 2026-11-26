import Foundation

/// Turns cumulative disk byte counters into per-second throughput.
/// The first reading after a gap only seeds the baseline, so it returns nil instead of a fake zero.
public struct DiskRateCalculator: Sendable {
    private var baseline: DiskCounters?

    public init() {}

    /// - Parameter current: nil when the disk counters could not be read this tick. The baseline is dropped,
    ///   so the first reading after the gap seeds a new one instead of averaging across the gap.
    public mutating func rates(for current: DiskCounters?, elapsedSeconds: Double) -> DiskRates? {
        guard let current else {
            baseline = nil
            return nil
        }
        defer { baseline = current }
        guard let previous = baseline, elapsedSeconds > 0 else { return nil }

        // Wrapping subtraction protects against counter resets.
        let readDelta = current.readBytes &- previous.readBytes
        let writeDelta = current.writeBytes &- previous.writeBytes
        return DiskRates(
            readBps: Double(readDelta) / elapsedSeconds,
            writeBps: Double(writeDelta) / elapsedSeconds
        )
    }
}
