import Foundation

/// Produces one `SystemSnapshot` per call by combining the ports with the domain calculators.
/// Holds the baselines needed for delta-based metrics (CPU ticks, interface counters, disk counters, timestamp).
/// Optional collectors that are not enabled are never read, so they cost nothing per tick.
public final class SampleSystemMetricsUseCase {
    private let sources: MetricSources

    private var previousTicks: CPUTicks?
    private var lastSampleNanos: UInt64?
    private var networkRates = NetworkRateCalculator()
    private var diskRates = DiskRateCalculator()
    private var filter: InterfaceFilter = .standard
    private var enabled: Set<CollectorKind> = []

    public init(sources: MetricSources) {
        self.sources = sources
    }

    /// Replaces the interface policy and the set of enabled optional collectors.
    /// Baselines are kept, so the next sample stays accurate.
    public func updateConfiguration(filter: InterfaceFilter, enabled: Set<CollectorKind>) {
        self.filter = filter
        self.enabled = enabled
    }

    /// The first call only establishes baselines, so its rates and CPU figure are zero.
    /// Disk rates stay nil until a second reading exists, because a fake zero would be misleading.
    public func execute() -> SystemSnapshot {
        let now = sources.clock.nanoseconds()
        let elapsedSeconds = lastSampleNanos.map { Double(now &- $0) / 1_000_000_000 } ?? 0
        lastSampleNanos = now

        var cpuPercent = 0.0
        if let ticks = sources.cpuTicks.readTicks() {
            if let previous = previousTicks {
                cpuPercent = CPUUsageCalculator.usage(previous: previous, current: ticks)
            }
            previousTicks = ticks
        }

        let rates = networkRates.rates(
            for: sources.interfaces.readInterfaces(),
            filter: filter,
            elapsedSeconds: elapsedSeconds
        )

        var snapshot = SystemSnapshot(
            cpuPercent: cpuPercent,
            memoryUsedBytes: sources.memory.readUsedBytes() ?? 0,
            downBps: rates.downBps,
            upBps: rates.upBps
        )

        if enabled.contains(.gpu) {
            snapshot.gpu = sources.gpu.read()
        }
        if enabled.contains(.memoryPressure) {
            snapshot.memoryPressure = sources.memoryPressure.readLevel()
        }
        if enabled.contains(.disk) {
            snapshot.disk = diskRates.rates(
                for: sources.disk.readCounters(),
                elapsedSeconds: elapsedSeconds
            )
        }
        if enabled.contains(.battery) {
            snapshot.battery = sources.battery.read()
        }
        if enabled.contains(.thermal) {
            // Non-blocking: returns the last completed background read, and schedules the next one.
            sources.thermal.requestRefresh()
            snapshot.thermal = sources.thermal.latest()
        }

        return snapshot
    }
}
