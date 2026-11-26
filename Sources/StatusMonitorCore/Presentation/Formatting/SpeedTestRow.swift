import Foundation

/// One labelled line of a speed test result, ready to show in the popover, Settings or the diagnostic output.
public struct SpeedTestRow: Equatable, Identifiable, Sendable {
    /// The name of the measurement, such as "Download".
    public let label: String
    /// The formatted value, such as "80.0 Mbit/s", or "--" when it was not measured.
    public let value: String

    /// The label names the row, so it is stable across refreshes.
    public var id: String { label }

    /**
     Creates a row.

     - Parameters:
       - label: The name of the measurement.
       - value: The formatted value.
     */
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}
