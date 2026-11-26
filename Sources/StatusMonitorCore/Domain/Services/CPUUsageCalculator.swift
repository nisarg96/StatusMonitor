import Foundation

/// Converts two cumulative tick samples into a busy percentage.
public enum CPUUsageCalculator {
    /// Busy percentage (0...100) between `previous` and `current`.
    /// If no ticks elapsed between the samples, returns 0.
    /// Counter deltas use wrapping subtraction so a 32-bit rollover does not produce garbage.
    public static func usage(previous: CPUTicks, current: CPUTicks) -> Double {
        let busy = Double(current.user &- previous.user)
            + Double(current.system &- previous.system)
            + Double(current.nice &- previous.nice)
        let idle = Double(current.idle &- previous.idle)
        let total = busy + idle
        guard total > 0 else { return 0 }
        return busy / total * 100
    }
}
