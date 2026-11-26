import Foundation

/**
 Pluggable predicate deciding which interfaces contribute to throughput totals.

 Swap the predicate to change policy (for example, to include loopback) without touching the sampler.
 */
public struct InterfaceFilter: Sendable {
    private let predicate: @Sendable (InterfaceCounters) -> Bool

    /**
     Creates a filter from a predicate.

     - Parameter predicate: Returns true for each interface that should count.
     */
    public init(_ predicate: @escaping @Sendable (InterfaceCounters) -> Bool) {
        self.predicate = predicate
    }

    /**
     Reports whether an interface contributes to throughput totals.

     - Parameter interface: The interface to check.
     - Returns: True when the predicate accepts the interface.
     */
    public func includes(_ interface: InterfaceCounters) -> Bool {
        predicate(interface)
    }

    /// Default policy: up, running, and not loopback.
    public static let standard = InterfaceFilter { info in
        info.isUp && info.isRunning && !info.isLoopback
    }

    /**
     Builds a filter from user settings.

     The filter accepts up and running interfaces. Loopback is accepted only when `includeLoopback` is on. When
     `allowedInterfaces` is not empty, only the listed names are accepted.

     - Parameter settings: The user's settings.
     - Returns: The filter for those settings.
     */
    public static func from(_ settings: MetricSettings) -> InterfaceFilter {
        let allowed = settings.allowedInterfaces
        let loopbackAllowed = settings.includeLoopback
        return InterfaceFilter { info in
            guard info.isUp, info.isRunning else { return false }
            if info.isLoopback && !loopbackAllowed { return false }
            if !allowed.isEmpty && !allowed.contains(info.name) { return false }
            return true
        }
    }
}
