import Foundation

/// Stores the daily traffic totals as JSON in UserDefaults.
public final class UserDefaultsDailyTrafficStore: DailyTrafficStore {
    private static let key = "dailyTraffic"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> DailyTraffic? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(DailyTraffic.self, from: data)
    }

    public func save(_ traffic: DailyTraffic) {
        guard let data = try? JSONEncoder().encode(traffic) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
