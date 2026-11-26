import Foundation

/// Persists the running daily network totals, so today's figure survives a restart.
public protocol DailyTrafficStore: AnyObject {
    func load() -> DailyTraffic?
    func save(_ traffic: DailyTraffic)
}
