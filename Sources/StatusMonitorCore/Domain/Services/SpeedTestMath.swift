import Foundation

/**
 Pure arithmetic for the internet speed test.

 Speed test results use decimal Mbit/s, where 1 Mbit = 10^6 bits. This is unlike the 1024-step rates used elsewhere
 in the app.
 */
public enum SpeedTestMath {
    /**
     Converts a byte count over a time window into decimal megabits per second.

     - Parameters:
       - bytes: The bytes transferred. Must not be negative.
       - seconds: The measured elapsed time. Must be greater than zero.
     - Returns: Megabits per second (10^6 bits), or nil when `seconds` is not positive or `bytes` is negative.
     */
    public static func mbps(bytes: Int64, seconds: Double) -> Double? {
        guard bytes >= 0, seconds > 0 else { return nil }
        return Double(bytes) * 8 / seconds / 1_000_000
    }

    /**
     Names the window rule in code: the mean rate over a measurement window, in decimal Mbit/s.

     - Parameters:
       - bytesReceived: The bytes received during the window. Must not be negative.
       - windowSeconds: The measured length of the window. Must be greater than zero.
     - Returns: Megabits per second, or nil under the same conditions as `mbps(bytes:seconds:)`.
     */
    public static func windowMean(bytesReceived: Int64, windowSeconds: Double) -> Double? {
        mbps(bytes: bytesReceived, seconds: windowSeconds)
    }

    /**
     Returns the median of the samples.

     - Parameter samples: The values to summarize. The array is not modified.
     - Returns: The middle value, or the mean of the two middle values for an even count. Nil when `samples` is empty.
     */
    public static func median(_ samples: [Double]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[middle]
        }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    /**
     Returns the jitter of latency samples, as the mean absolute difference between consecutive samples.

     - Parameter samplesInSendOrder: The latency samples, in the order they were sent.
     - Returns: The mean of the absolute differences between neighbouring samples, or nil with fewer than 2 samples.
     */
    public static func jitter(_ samplesInSendOrder: [Double]) -> Double? {
        guard samplesInSendOrder.count >= 2 else { return nil }
        var total = 0.0
        for index in 1..<samplesInSendOrder.count {
            total += abs(samplesInSendOrder[index] - samplesInSendOrder[index - 1])
        }
        return total / Double(samplesInSendOrder.count - 1)
    }

    /**
     Removes the server's processing time from a measured round trip.

     - Parameters:
       - roundTripMs: The measured round trip, in milliseconds.
       - serverTimingMs: The server's reported processing time, in milliseconds. Nil when the server did not report it.
     - Returns: The round trip minus the server time, clamped at 0. The round trip itself when `serverTimingMs` is nil.
     */
    public static func latencyFromServerTiming(roundTripMs: Double, serverTimingMs: Double?) -> Double {
        guard let serverTimingMs else { return roundTripMs }
        return max(0, roundTripMs - serverTimingMs)
    }

    /**
     Reports whether the last three rates agree closely enough to call the measurement settled.

     Each of the last three values must lie within `tolerance` of their mean, measured relative to that mean.

     - Parameters:
       - rates: The rates measured so far, oldest first. Only the last three are checked.
       - tolerance: The allowed relative deviation from the mean. Defaults to 0.10 (10%).
     - Returns: True when there are at least three values and the last three are within tolerance. False otherwise.
     */
    public static func isStable(_ rates: [Double], tolerance: Double = 0.10) -> Bool {
        guard rates.count >= 3 else { return false }
        let window = rates.suffix(3)
        let mean = window.reduce(0, +) / 3
        return window.allSatisfy { abs($0 - mean) <= tolerance * abs(mean) }
    }

    /**
     Computes the share of probe packets that did not come back.

     - Parameters:
       - sent: The number of packets sent.
       - received: The number of packets that came back. Must not be negative or greater than `sent`.
     - Returns: The loss as a percentage, 0...100. Nil when `sent` is zero, or when `received` is out of range.
     */
    public static func packetLossPercent(sent: Int, received: Int) -> Double? {
        guard sent > 0, received >= 0, received <= sent else { return nil }
        return Double(sent - received) * 100 / Double(sent)
    }
}
