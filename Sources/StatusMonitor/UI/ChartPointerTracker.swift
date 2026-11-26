import Combine
import Foundation

/// Holds the pointer's x position over a chart, or nil when the pointer is off it. A class, so the chart can keep it
/// with `@StateObject` (the SwiftUI `@State` macro is not available to this build).
final class ChartPointerTracker: ObservableObject {
    @Published var position: Double?
}
