import Foundation

/// Stores the daily traffic totals as JSON in UserDefaults, so today's figure survives a restart.
public final class UserDefaultsDailyTrafficStore: DailyTrafficStore {
    private static let key = "dailyTraffic"
    private let defaults: UserDefaults

    /**
     Creates a store backed by a UserDefaults domain.

     - Parameters:
       - defaults: The defaults database to read and write. Tests pass a suite-named instance.
     */
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /**
     Loads the stored totals.

     - Returns: The saved totals, or nil when nothing is stored or the stored JSON cannot be decoded.
     */
    public func load() -> DailyTraffic? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(DailyTraffic.self, from: data)
    }

    /**
     Saves the totals as JSON, replacing any earlier value.

     If the value cannot be encoded, the previously stored value is left in place.

     - Parameters:
       - traffic: The totals to store.
     */
    public func save(_ traffic: DailyTraffic) {
        guard let data = try? JSONEncoder().encode(traffic) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
