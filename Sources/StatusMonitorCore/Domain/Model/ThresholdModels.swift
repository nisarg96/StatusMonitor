import Foundation

/// Display state for a metric. `normal` means no colour at all, so it follows the system default.
public enum ReadoutAccent: Equatable, Sendable {
    case normal
    case warning
    case critical

    /// Severity order, used by the stabiliser to tell up from down.
    public var rank: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}
