import Foundation

/// Recent values for one series, each with the wall-clock time it was recorded. Capped like `SampleHistory`.
public struct TimedSampleHistory: Equatable, Sendable {
    public struct Sample: Equatable, Sendable {
        public let time: Date
        public let value: Double
    }

    public private(set) var samples: [Sample] = []

    public init() {}

    public var values: [Double] { samples.map(\.value) }
    public var times: [Date] { samples.map(\.time) }

    /// The value at an index, or nil when the index is out of range. Never a zero for a missing sample.
    public func value(at index: Int) -> Double? {
        samples.indices.contains(index) ? samples[index].value : nil
    }

    public mutating func append(_ value: Double, at time: Date) {
        samples.append(Sample(time: time, value: value))
        if samples.count > SampleHistory.capacity {
            samples.removeFirst(samples.count - SampleHistory.capacity)
        }
    }
}
