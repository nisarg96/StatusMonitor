import Foundation

/// Runs once at launch to decide which optional collectors this Mac can provide.
/// A collector counts as available only when its read succeeds right now.
/// Run it off the main thread, because the thermal probe opens the SMC.
public struct CapabilityProbe {
    private let sources: MetricSources

    public init(sources: MetricSources) {
        self.sources = sources
    }

    public func run() -> MetricCapabilities {
        var available = Set<CollectorKind>()

        if sources.gpu.read() != nil { available.insert(.gpu) }
        if sources.memoryPressure.readLevel() != nil { available.insert(.memoryPressure) }
        if sources.disk.readCounters() != nil { available.insert(.disk) }
        if sources.battery.read() != nil { available.insert(.battery) }
        if sources.thermal.probe() { available.insert(.thermal) }

        return MetricCapabilities(available: available)
    }
}
