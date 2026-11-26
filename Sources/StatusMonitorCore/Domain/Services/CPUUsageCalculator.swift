import Foundation

/// Converts two cumulative tick samples into a busy percentage.
public enum CPUUsageCalculator {
    /**
     Returns the busy CPU percentage between two tick samples.

     If no ticks elapsed between the samples, the result is 0. Counter deltas use wrapping subtraction, so a 32-bit
     rollover does not produce garbage.

     - Parameters:
       - previous: The earlier sample.
       - current: The later sample.
     - Returns: The busy percentage, 0...100.
     */
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
