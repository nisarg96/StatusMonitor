import Foundation

/// Persists the global clean timestamp and the purge-permission prompt choice in UserDefaults.
public final class UserDefaultsRemediationStore {
    /// UserDefaults keys for this store. Renaming one orphans the value the user already saved.
    enum Key {
        static let lastCleanAt = "remediation.lastCleanAt"
        static let purgePermissionPromptDeclined = "remediation.purgePermissionPromptDeclined"
    }

    private let defaults: UserDefaults

    /**
     Creates a store backed by a UserDefaults domain.

     - Parameters:
       - defaults: The defaults database to read and write.
     */
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Global timestamps

    /// Time of the last clean, in seconds since 1970 (Unix epoch). Nil when no clean has been recorded.
    public var lastCleanAt: Double? {
        get { defaults.object(forKey: Key.lastCleanAt) as? Double }
        set { set(newValue, forKey: Key.lastCleanAt) }
    }

    /// Whether the user chose "Not now" on the launch-time purge permission prompt. Settings still offers Install.
    public var purgePermissionPromptDeclined: Bool {
        get { defaults.bool(forKey: Key.purgePermissionPromptDeclined) }
        set { defaults.set(newValue, forKey: Key.purgePermissionPromptDeclined) }
    }

    /// Stores the value under the key, or removes the key when the value is nil.
    private func set(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
