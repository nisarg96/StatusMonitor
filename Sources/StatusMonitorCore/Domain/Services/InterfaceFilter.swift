import Foundation

/// Pluggable predicate deciding which interfaces contribute to throughput totals.
/// Swap the predicate to change policy (e.g. include loopback) without touching the sampler.
public struct InterfaceFilter: Sendable {
    private let predicate: @Sendable (InterfaceCounters) -> Bool

    public init(_ predicate: @escaping @Sendable (InterfaceCounters) -> Bool) {
        self.predicate = predicate
    }

    public func includes(_ interface: InterfaceCounters) -> Bool {
        predicate(interface)
    }

    /// Default policy: up, running, and not loopback.
    public static let standard = InterfaceFilter { info in
        info.isUp && info.isRunning && !info.isLoopback
    }

    /// Policy derived from user settings: up and running, optional loopback,
    /// and optional allow-list of interface names.
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
