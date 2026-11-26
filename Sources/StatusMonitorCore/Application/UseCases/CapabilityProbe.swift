import Foundation

/**
 Decides which optional collectors this Mac can provide.

 The probe runs once at launch. A collector counts as available only when its read succeeds at that moment. Run it off
 the main thread, because the thermal probe opens the SMC.
 */
public struct CapabilityProbe {
    private let sources: MetricSources

    /**
     Creates a probe.

     - Parameter sources: The ports to probe.
     */
    public init(sources: MetricSources) {
        self.sources = sources
    }

    /**
     Probes each optional collector once.

     - Returns: The collectors whose read succeeded. CPU, RAM and network are always available, so they are not listed.
     */
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
