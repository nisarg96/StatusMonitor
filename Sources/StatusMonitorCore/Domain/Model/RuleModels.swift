import Foundation

/// Metrics a rule can watch.
public enum RuleMetric: String, Codable, CaseIterable, Sendable {
    case cpuPercent
    case memoryPressure
    case diskFreeGB
    case diskFreePercent
    case swapUsedGB
    case batteryHealth
}

public enum RuleComparator: String, Codable, CaseIterable, Sendable {
    case greaterThan
    case greaterOrEqual
    case lessThan
    case lessOrEqual

    public func holds(_ value: Double, _ threshold: Double) -> Bool {
        switch self {
        case .greaterThan: return value > threshold
        case .greaterOrEqual: return value >= threshold
        case .lessThan: return value < threshold
        case .lessOrEqual: return value <= threshold
        }
    }
}

public enum CleanPreset: String, Codable, CaseIterable, Sendable {
    case standard
    case extreme
}

/// What a rule does when it fires.
public enum RuleAction: Codable, Equatable, Sendable {
    case notify
    case script(path: String)
    case clean(CleanPreset)

    /// Floor on the cooldown for this action. Enforced in code, so a user cannot set a shorter cooldown.
    public var cooldownFloorSeconds: Double {
        switch self {
        case .notify: return 60
        case .script: return 300
        case .clean: return 180
        }
    }
}

/// A user-defined rule: WHEN metric comparator threshold FOR sustainSeconds THEN action.
/// Identified by a stable UUID, so renaming or editing never orphans its runtime state.
public struct Rule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var metric: RuleMetric
    public var comparator: RuleComparator
    public var threshold: Double
    public var sustainSeconds: Double
    public var action: RuleAction
    public var cooldownSeconds: Double
    /// Dry-run is on by default. A dry-run fire is logged and notified, but the action is not executed.
    public var dryRun: Bool
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        metric: RuleMetric,
        comparator: RuleComparator,
        threshold: Double,
        sustainSeconds: Double,
        action: RuleAction,
        cooldownSeconds: Double,
        dryRun: Bool = true,
        enabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.metric = metric
        self.comparator = comparator
        self.threshold = threshold
        self.sustainSeconds = sustainSeconds
        self.action = action
        self.cooldownSeconds = cooldownSeconds
        self.dryRun = dryRun
        self.enabled = enabled
    }

    /// The cooldown actually applied: the user's value, but never below the action's floor.
    public var effectiveCooldownSeconds: Double {
        max(cooldownSeconds, action.cooldownFloorSeconds)
    }
}

/// Per-rule runtime state. Kept separate from the rule definition, so editing a rule never rewrites it.
public struct RuleRuntimeState: Codable, Equatable, Sendable {
    /// Seconds the condition has held continuously. Reset to 0 when it breaks.
    public var streakSeconds: Double
    /// Wall-clock time (epoch seconds) of the last fire. Wall-clock, so the cooldown survives restarts.
    public var lastFiredAt: Double?

    public init(streakSeconds: Double = 0, lastFiredAt: Double? = nil) {
        self.streakSeconds = streakSeconds
        self.lastFiredAt = lastFiredAt
    }
}
