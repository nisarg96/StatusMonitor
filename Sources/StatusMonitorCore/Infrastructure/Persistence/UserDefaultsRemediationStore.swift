import Foundation

/// Persists the global clean timestamp. Other remediation state has no production callers and was removed.
public final class UserDefaultsRemediationStore {
    enum Key {
        static let lastCleanAt = "remediation.lastCleanAt"
        static let purgePermissionPromptDeclined = "remediation.purgePermissionPromptDeclined"
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

    /// True once the user chose "Not now" on the launch-time purge permission prompt. Settings still offers Install.
    public var purgePermissionPromptDeclined: Bool {
        get { defaults.bool(forKey: Key.purgePermissionPromptDeclined) }
        set { defaults.set(newValue, forKey: Key.purgePermissionPromptDeclined) }
    }

    private func set(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
