import Foundation
@testable import StatusMonitorCore

// Deterministic test doubles for every port. None of them touches the system.

final class FakeCPUTickSource: CPUTickSource {
    var queued: [CPUTicks?] = []

    func readTicks() -> CPUTicks? {
        guard !queued.isEmpty else { return nil }
        return queued.removeFirst()
    }
}

final class FakeMemoryUsageSource: MemoryUsageSource {
    var usedBytes: UInt64? = 0

    func readUsedBytes() -> UInt64? { usedBytes }
}

final class FakeInterfaceCounterSource: InterfaceCounterSource {
    var interfaces: [InterfaceCounters] = []

    func readInterfaces() -> [InterfaceCounters] { interfaces }
}

final class FakeClock: MonotonicClock {
    var nanos: UInt64 = 0

    func nanoseconds() -> UInt64 { nanos }

    func advance(seconds: Double) {
        nanos += UInt64(seconds * 1_000_000_000)
    }
}

final class FakeGPUSource: GPUSource {
    var reading: GPUReading?
    private(set) var reads = 0

    func read() -> GPUReading? {
        reads += 1
        return reading
    }
}

final class FakeMemoryPressureSource: MemoryPressureSource {
    var level: MemoryPressureLevel?
    private(set) var reads = 0

    func readLevel() -> MemoryPressureLevel? {
        reads += 1
        return level
    }
}

final class FakeDiskCounterSource: DiskCounterSource {
    var counters: DiskCounters?
    private(set) var reads = 0

    func readCounters() -> DiskCounters? {
        reads += 1
        return counters
    }
}

final class FakeBatterySource: BatterySource {
    var reading: BatteryReading?
    private(set) var reads = 0

    func read() -> BatteryReading? {
        reads += 1
        return reading
    }
}

final class FakeThermalSource: ThermalSource {
    var probeResult = false
    var reading: ThermalReading?
    private(set) var refreshRequests = 0

    func probe() -> Bool { probeResult }
    func latest() -> ThermalReading? { reading }
    func requestRefresh() { refreshRequests += 1 }
}

final class InMemorySettingsRepository: SettingsRepository {
    var stored: MetricSettings
    private(set) var saveCount = 0

    init(_ initial: MetricSettings = MetricSettings()) {
        stored = initial
    }

    func load() -> MetricSettings { stored }

    func save(_ settings: MetricSettings) {
        stored = settings
        saveCount += 1
    }
}

final class FakeRefreshScheduler: RefreshScheduling {
    private(set) var interval: TimeInterval?
    private(set) var scheduleCount = 0
    private var action: (() -> Void)?

    func schedule(every interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
        scheduleCount += 1
    }

    func cancel() {
        action = nil
        interval = nil
    }

    /// Simulates one timer firing.
    func fire() {
        action?()
    }
}

/// Bundles fakes into `MetricSources`, keeping the individual fakes reachable for configuration.
struct FakeSources {
    let cpu = FakeCPUTickSource()
    let memory = FakeMemoryUsageSource()
    let interfaces = FakeInterfaceCounterSource()
    let clock = FakeClock()
    let gpu = FakeGPUSource()
    let pressure = FakeMemoryPressureSource()
    let disk = FakeDiskCounterSource()
    let battery = FakeBatterySource()
    let thermal = FakeThermalSource()

    var sources: MetricSources {
        MetricSources(
            cpuTicks: cpu, memory: memory, interfaces: interfaces, clock: clock,
            gpu: gpu, memoryPressure: pressure, disk: disk, battery: battery, thermal: thermal
        )
    }
}

extension InterfaceCounters {
    static func active(_ name: String, rx: UInt32 = 0, tx: UInt32 = 0) -> InterfaceCounters {
        InterfaceCounters(name: name, isUp: true, isRunning: true, isLoopback: false, rxBytes: rx, txBytes: tx)
    }

    static func loopback(rx: UInt32 = 0, tx: UInt32 = 0) -> InterfaceCounters {
        InterfaceCounters(name: "lo0", isUp: true, isRunning: true, isLoopback: true, rxBytes: rx, txBytes: tx)
    }
}
