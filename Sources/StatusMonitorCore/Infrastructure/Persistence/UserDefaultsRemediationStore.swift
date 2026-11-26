import Foundation

/// Persists rule definitions, per-rule runtime state, global script and clean timestamps, and one-time confirmations.
/// Runtime state is keyed by rule UUID and stored separately from definitions. Editing a rule never touches it.
public final class UserDefaultsRemediationStore {
    enum Key {
        static let rules = "remediation.rules"
        static func runtime(_ id: UUID) -> String { "remediation.runtime.\(id.uuidString)" }
        static let lastScriptRunAt = "remediation.lastScriptRunAt"
        static let lastCleanAt = "remediation.lastCleanAt"
        static let confirmedScriptRules = "remediation.confirmedScriptRules"
        static let confirmedExtremeClean = "remediation.confirmedExtremeClean"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Rules

    public func loadRules() -> [Rule] {
        guard let data = defaults.data(forKey: Key.rules),
              let rules = try? decoder.decode([Rule].self, from: data) else { return [] }
        return rules
    }

    public func saveRules(_ rules: [Rule]) {
        guard let data = try? encoder.encode(rules) else { return }
        defaults.set(data, forKey: Key.rules)
    }

    // MARK: - Runtime

    public func loadRuntime(for id: UUID) -> RuleRuntimeState {
        guard let data = defaults.data(forKey: Key.runtime(id)),
              let state = try? decoder.decode(RuleRuntimeState.self, from: data) else {
            return RuleRuntimeState()
        }
        return state
    }

    public func saveRuntime(_ state: RuleRuntimeState, for id: UUID) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: Key.runtime(id))
    }

    public func removeRuntime(for id: UUID) {
        defaults.removeObject(forKey: Key.runtime(id))
    }

    // MARK: - Global timestamps

    public var lastScriptRunAt: Double? {
        get { defaults.object(forKey: Key.lastScriptRunAt) as? Double }
        set { set(newValue, forKey: Key.lastScriptRunAt) }
    }

    public var lastCleanAt: Double? {
        get { defaults.object(forKey: Key.lastCleanAt) as? Double }
        set { set(newValue, forKey: Key.lastCleanAt) }
    }

    // MARK: - One-time confirmations

    public var hasConfirmedScriptRules: Bool {
        get { defaults.bool(forKey: Key.confirmedScriptRules) }
        set { defaults.set(newValue, forKey: Key.confirmedScriptRules) }
    }

    public var hasConfirmedExtremeClean: Bool {
        get { defaults.bool(forKey: Key.confirmedExtremeClean) }
        set { defaults.set(newValue, forKey: Key.confirmedExtremeClean) }
    }

    private func set(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
