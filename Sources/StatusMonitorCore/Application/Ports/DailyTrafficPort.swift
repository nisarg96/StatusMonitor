import Foundation

/// Persists the running daily network totals, so today's figure survives a restart.
public protocol DailyTrafficStore: AnyObject {
    /**
     Loads the stored totals.

     - Returns: The stored totals, or nil when none are stored.
     */
    func load() -> DailyTraffic?

    /**
     Saves the totals, replacing any earlier value.

     - Parameter traffic: The totals to store.
     */
    func save(_ traffic: DailyTraffic)
}
