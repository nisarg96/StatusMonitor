import StatusMonitorCore
import SwiftUI

/// One line of an interactive chart: its own timed samples, colour and dash style.
struct ChartLine: Identifiable {
    /// The line's identifier, which is also used as its dot's identity.
    let id: String
    /// The timed samples of this line.
    let history: TimedSampleHistory
    /// The line's colour.
    let color: Color
    /// Draws the line dashed when true.
    var dashed = false
}

/**
 A sparkline that follows the pointer.

 Hovering shows a guide at the nearest sample, a dot on each line, and a tooltip with that sample's time and values.
 The nearest sample and the tooltip text come from `ChartHover`. It uses `onContinuousHover`, so it runs on macOS 13.
 */
struct ChartHoverChart: View {
    /// The lines to draw. The tooltip's time comes from the first line.
    let lines: [ChartLine]
    /// Fixed scale for percentages. Nil fits the data.
    let yDomain: ClosedRange<Double>?
    /// The height of the chart, in points.
    var height: CGFloat = 34
    /// Returns the value text for the sample at an index of the first line.
    let tooltip: (Int) -> [String]

    @StateObject private var pointer = ChartPointerTracker()

    var body: some View {
        GeometryReader { proxy in
            let width = Double(proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(lines) { line in
                    SparklineShape(history: line.history, domain: domain)
                        .stroke(line.color, style: StrokeStyle(
                            lineWidth: 1.5, lineCap: .round, lineJoin: .round,
                            dash: line.dashed ? [4, 3] : []
                        ))
                }
                if let pointerX = pointer.position, let readout = ChartHover.readout(
                    atX: pointerX, width: width, times: primaryTimes, parts: tooltip
                ) {
                    HoverOverlay(
                        readout: readout, lines: lines, domain: domain,
                        width: width, height: Double(height), pointerX: pointerX
                    )
                }
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): pointer.position = Double(location.x)
                case .ended: pointer.position = nil
                }
            }
        }
        .frame(height: height)
    }

    private var primaryTimes: [Date] {
        lines.first?.history.times ?? []
    }

    /// The fixed domain, or 0 to the peak across all lines (at least 1, so a flat line is not divided by zero).
    private var domain: ClosedRange<Double> {
        if let yDomain { return yDomain }
        let peak = lines.flatMap { $0.history.values }.max() ?? 1
        return 0...max(1, peak)
    }
}

/// The guide, dots and tooltip for one hovered sample.
private struct HoverOverlay: View {
    /// The hovered sample's index and its tooltip text.
    let readout: ChartHover.Readout
    /// The lines whose dots are drawn at the hovered sample.
    let lines: [ChartLine]
    /// The y scale that the dots are placed with.
    let domain: ClosedRange<Double>
    /// The chart's width, in points.
    let width: Double
    /// The chart's height, in points.
    let height: Double
    /// The pointer's x position, in points, used when the guide has no sample time to snap to.
    let pointerX: Double

    var body: some View {
        let times = lines.first?.history.times ?? []
        let guideX = guideXPosition(times: times)
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: guideX, y: 0))
                path.addLine(to: CGPoint(x: guideX, y: height))
            }
            .stroke(PopoverPalette.secondaryText.opacity(0.6), lineWidth: 1)

            ForEach(dots(), id: \.id) { dot in
                Circle()
                    .fill(dot.color)
                    .frame(width: 6, height: 6)
                    .position(x: dot.xPos, y: dot.yPos)
            }

            ChartTooltipBox(readout: readout, guideX: guideX, width: width)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func guideXPosition(times: [Date]) -> Double {
        guard readout.index < times.count else { return pointerX }
        return ChartHover.xPosition(forTime: times[readout.index], width: width, times: times) ?? pointerX
    }

    private func dots() -> [HoverDot] {
        lines.compactMap { line in
            guard let sample = line.history.samples[safe: readout.index] else { return nil }
            let times = line.history.times
            let xPos = ChartHover.xPosition(forTime: sample.time, width: width, times: times) ?? 0
            let yPos = ChartHover.yPosition(value: sample.value, domain: domain, height: height)
            return HoverDot(id: line.id, color: line.color, xPos: xPos, yPos: yPos)
        }
    }
}

private struct HoverDot {
    let id: String
    let color: Color
    let xPos: Double
    let yPos: Double
}

/**
 The tooltip, placed on the side of the guide with the most room, so it stays inside the chart.

 It sits 6 points clear of the guide.
 */
private struct ChartTooltipBox: View {
    /// The hovered sample's time and value text.
    let readout: ChartHover.Readout
    /// The guide's x position, in points.
    let guideX: Double
    /// The chart's width, in points.
    let width: Double

    var body: some View {
        let onLeft = guideX < width / 2
        let inset = onLeft ? guideX + 6 : width - guideX + 6
        box
            .padding(.leading, onLeft ? inset : 0)
            .padding(.trailing, onLeft ? 0 : inset)
            .frame(width: width, alignment: onLeft ? .leading : .trailing)
    }

    private var box: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(readout.timeText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(PopoverPalette.secondaryText)
            Text(readout.valueText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(PopoverPalette.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(PopoverPalette.tooltipFill))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(PopoverPalette.cardBorder, lineWidth: 1))
    }
}

private extension Array {
    /// The element at an index, or nil when out of range.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
