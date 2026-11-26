import Foundation

/// Persists the global clean timestamp. Other remediation state has no production callers and was removed.
public final class UserDefaultsRemediationStore {
    enum Key {
        static let lastCleanAt = "remediation.lastCleanAt"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Global timestamps

    public var lastCleanAt: Double? {
        get { defaults.object(forKey: Key.lastCleanAt) as? Double }
        set { set(newValue, forKey: Key.lastCleanAt) }
    }

    private func set(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
