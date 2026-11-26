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

/// Metrics that can carry alert thresholds.
public enum MetricID: String, CaseIterable, Codable, Sendable {
    case cpuPercent
    case ramPercent
    case gpuPercent
    case batteryCharge
    case batteryHealth
    case networkDown
    case networkUp
    case diskRead
    case diskWrite
    case cpuTemperature
}

public enum ThresholdDirection: Equatable, Sendable {
    /// Alert when the value rises to the line, e.g. CPU %.
    case higherIsWorse
    /// Alert when the value falls to the line, e.g. battery charge.
    case lowerIsWorse
}

/// Warning and critical lines for one metric. A nil line is simply not checked.
public struct ThresholdSpec: Equatable, Codable, Sendable {
    public var warning: Double?
    public var critical: Double?

    public init(warning: Double?, critical: Double?) {
        self.warning = warning
        self.critical = critical
    }

    /// True when neither line is set, which means the metric is never coloured.
    public var isOff: Bool { warning == nil && critical == nil }
}

/// Starting points from the design review. They are defaults, not facts, and the user can change every one.
public enum ThresholdDefaults {
    public static func direction(for metric: MetricID) -> ThresholdDirection {
        switch metric {
        case .batteryCharge, .batteryHealth: return .lowerIsWorse
        default: return .higherIsWorse
        }
    }

    /// Network and disk are opt-in, so their default is off. Fast transfers are not a problem by themselves.
    public static func spec(for metric: MetricID) -> ThresholdSpec? {
        switch metric {
        case .cpuPercent: return ThresholdSpec(warning: 70, critical: 90)
        case .ramPercent: return ThresholdSpec(warning: 80, critical: 90)
        case .gpuPercent: return ThresholdSpec(warning: 80, critical: 95)
        case .batteryCharge: return ThresholdSpec(warning: 20, critical: 10)
        case .batteryHealth: return ThresholdSpec(warning: 80, critical: 70)
        case .cpuTemperature: return ThresholdSpec(warning: 90, critical: 100)
        case .networkDown, .networkUp, .diskRead, .diskWrite: return nil
        }
    }
}
