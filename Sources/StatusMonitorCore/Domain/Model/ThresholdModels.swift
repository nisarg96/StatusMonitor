import Foundation

/// Display state for a metric. `normal` means no colour at all, so it follows the system default.
public enum ReadoutAccent: Equatable, Sendable {
    /// No colour. The system default applies.
    case normal
    /// The metric is near its threshold.
    case warning
    /// The metric is at or past its threshold.
    case critical

    /// Severity order, used by the stabiliser to tell up from down. Higher rank is more severe.
    public var rank: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}
