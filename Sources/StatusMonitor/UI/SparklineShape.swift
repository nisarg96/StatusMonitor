import StatusMonitorCore
import SwiftUI

/// A line through one series' samples. X comes from each sample's time (see `ChartHover`), so the drawing and the
/// hover guide use the same positions.
struct SparklineShape: Shape {
    let history: TimedSampleHistory
    let domain: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let times = history.times
        let width = Double(rect.width)
        let height = Double(rect.height)
        for (index, sample) in history.samples.enumerated() {
            let xPos = ChartHover.xPosition(forTime: sample.time, width: width, times: times) ?? 0
            let yPos = ChartHover.yPosition(value: sample.value, domain: domain, height: height)
            let point = CGPoint(x: xPos, y: yPos)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
