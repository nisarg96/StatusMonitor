import Foundation

/**
 Recent values for one series, each with the wall-clock time it was recorded.

 Capped like `SampleHistory`.
 */
public struct TimedSampleHistory: Equatable, Sendable {
    /// One value and the wall-clock time it was recorded.
    public struct Sample: Equatable, Sendable {
        /// When the value was recorded.
        public let time: Date
        /// The recorded value.
        public let value: Double
    }

    /// The stored samples, oldest first.
    public private(set) var samples: [Sample] = []

    /// Creates an empty history.
    public init() {}

    /// The values, oldest first, without their times.
    public var values: [Double] { samples.map(\.value) }
    /// The times, in the same order as `values`.
    public var times: [Date] { samples.map(\.time) }

    /**
     Returns the value at an index.

     - Parameters:
       - index: The position in `samples`, oldest first.
     - Returns: The value, or nil when the index is out of range. Never a zero for a missing sample.
     */
    public func value(at index: Int) -> Double? {
        samples.indices.contains(index) ? samples[index].value : nil
    }

    /**
     Appends a sample, dropping the oldest once `SampleHistory.capacity` is reached.

     - Parameters:
       - value: The value to record.
       - time: The wall-clock time the value was recorded.
     */
    public mutating func append(_ value: Double, at time: Date) {
        samples.append(Sample(time: time, value: value))
        if samples.count > SampleHistory.capacity {
            samples.removeFirst(samples.count - SampleHistory.capacity)
        }
    }
}
