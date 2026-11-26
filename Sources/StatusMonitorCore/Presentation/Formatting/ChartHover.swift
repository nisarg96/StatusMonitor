import Foundation

/// Maps pointer positions to chart samples. Pure: no AppKit or SwiftUI.
///
/// Samples are placed by their wall-clock time, not by their index. The left edge of a chart is the oldest sample
/// and the right edge is the newest, so a gap after sleep is drawn and hovered at its real position.
public enum ChartHover {
    /// What the tooltip shows for one sample.
    public struct Readout: Equatable, Sendable {
        public let index: Int
        /// The sample's own time, for example "00:53:12".
        public let timeText: String
        /// The values at that sample, joined with ", ".
        public let valueText: String
    }

    /// The sample nearest in time to the pointer. The pointer is clamped to the chart, so positions beyond either
    /// edge select the first or last sample. Nil when there are no samples or the chart has no width.
    public static func index(atX position: Double, width: Double, times: [Date]) -> Int? {
        guard !times.isEmpty, width > 0 else { return nil }
        let stamps = times.map(\.timeIntervalSince1970)
        guard let low = stamps.min(), let high = stamps.max() else { return nil }
        let span = high - low
        guard span > 0 else { return 0 }

        let target = low + clamp(position / width, 0, 1) * span
        var best = 0
        var bestDistance = Double.infinity
        for (offset, stamp) in stamps.enumerated() where abs(stamp - target) < bestDistance {
            best = offset
            bestDistance = abs(stamp - target)
        }
        return best
    }

    /// The x position of a sample's time within the chart. A single sample sits at the right edge, the newest point.
    /// Nil when there are no samples.
    public static func xPosition(forTime time: Date, width: Double, times: [Date]) -> Double? {
        let stamps = times.map(\.timeIntervalSince1970)
        guard let low = stamps.min(), let high = stamps.max() else { return nil }
        let span = high - low
        guard span > 0 else { return width }
        return clamp((time.timeIntervalSince1970 - low) / span, 0, 1) * width
    }

    /// The tooltip for the sample under the pointer. `parts` gives the value text for each sample index.
    public static func readout(
        atX position: Double,
        width: Double,
        times: [Date],
        timeZone: TimeZone = .current,
        parts: (Int) -> [String]
    ) -> Readout? {
        guard let index = index(atX: position, width: width, times: times) else { return nil }
        return Readout(
            index: index,
            timeText: timeText(times[index], timeZone: timeZone),
            valueText: parts(index).joined(separator: ", ")
        )
    }

    /// "HH:mm:ss" in the given time zone.
    public static func timeText(_ time: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: time)
        return String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }

    /// The y position of a value in a chart of the given height. The top of the domain is y = 0. A flat domain
    /// sits at the middle.
    public static func yPosition(value: Double, domain: ClosedRange<Double>, height: Double) -> Double {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return height / 2 }
        let fraction = clamp((value - domain.lowerBound) / span, 0, 1)
        return height * (1 - fraction)
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}
