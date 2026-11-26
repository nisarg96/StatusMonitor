import Combine
import Foundation

/**
 Holds the pointer's x position over a chart, or nil when the pointer is off it.

 It is a class, so the chart can keep it with `@StateObject`. The SwiftUI `@State` macro is not available to this build.
 */
final class ChartPointerTracker: ObservableObject {
    /// The pointer's x position in points, or nil when the pointer is off the chart.
    @Published var position: Double?
}
