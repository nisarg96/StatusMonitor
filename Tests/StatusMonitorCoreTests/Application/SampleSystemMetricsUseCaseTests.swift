import Testing
@testable import StatusMonitorCore

@Suite("SampleSystemMetricsUseCase")
struct SampleSystemMetricsUseCaseTests {
    private struct Rig {
        let fakes = FakeSources()
        let useCase: SampleSystemMetricsUseCase

        init() {
            useCase = SampleSystemMetricsUseCase(sources: fakes.sources)
        }
    }

    @Test("first execution establishes baselines and reports zero rates and CPU")
    func firstExecutionIsBaseline() {
        let rig = Rig()
        rig.fakes.cpu.queued = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 1_000, tx: 1_000)]
        let snapshot = rig.useCase.execute()
        #expect(snapshot.cpuPercent == 0)
        #expect(snapshot.downBps == 0)
        #expect(snapshot.upBps == 0)
    }

    @Test("second execution reports CPU and rates over the clock interval")
    func secondExecutionComputesDeltas() {
        let rig = Rig()
        rig.fakes.cpu.queued = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 25, system: 0, idle: 75, nice: 0),
        ]
        rig.fakes.memory.usedBytes = 3_221_225_472
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 0, tx: 0)]
        _ = rig.useCase.execute()

        rig.fakes.clock.advance(seconds: 2)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 4_000, tx: 2_000)]
        let snapshot = rig.useCase.execute()

        #expect(snapshot.cpuPercent == 25)
        #expect(snapshot.memoryUsedBytes == 3_221_225_472)
        #expect(snapshot.downBps == 2_000)
        #expect(snapshot.upBps == 1_000)
    }

    @Test("a failed CPU read reports 0% without crashing")
    func cpuReadFailure() {
        let rig = Rig()
        rig.fakes.cpu.queued = [nil]
        #expect(rig.useCase.execute().cpuPercent == 0)
    }

    @Test("updated filter changes which interfaces are counted")
    func filterUpdateApplies() {
        let rig = Rig()
        rig.fakes.interfaces.interfaces = [.active("en0"), .active("utun3")]
        _ = rig.useCase.execute()

        rig.useCase.updateConfiguration(filter: InterfaceFilter { $0.name == "utun3" }, enabled: [])
        rig.fakes.clock.advance(seconds: 1)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 9_000), .active("utun3", rx: 500)]
        #expect(rig.useCase.execute().downBps == 500)
    }

    // MARK: - Optional collectors

    @Test("disabled optional collectors are never read, so they cost nothing per tick")
    func disabledCollectorsAreNotRead() {
        let rig = Rig()
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 40)
        rig.fakes.battery.reading = sampleBattery
        _ = rig.useCase.execute()

        #expect(rig.fakes.gpu.reads == 0)
        #expect(rig.fakes.battery.reads == 0)
        #expect(rig.fakes.thermal.refreshRequests == 0)
    }

    @Test("enabled collectors populate their snapshot fields")
    func enabledCollectorsPopulate() {
        let rig = Rig()
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 40)
        rig.fakes.pressure.level = .warning
        rig.fakes.battery.reading = sampleBattery
        rig.fakes.thermal.reading = ThermalReading(cpuTemperatureC: 51, fans: [FanSpeed(index: 0, rpm: 2100)])
        rig.useCase.updateConfiguration(
            filter: .standard,
            enabled: [.gpu, .memoryPressure, .battery, .thermal]
        )

        let snapshot = rig.useCase.execute()
        #expect(snapshot.gpu?.utilizationPercent == 40)
        #expect(snapshot.memoryPressure == .warning)
        #expect(snapshot.battery == sampleBattery)
        #expect(snapshot.thermal?.cpuTemperatureC == 51)
    }

    @Test("a collector that reports nil stays nil, never zero")
    func unavailableCollectorStaysNil() {
        let rig = Rig()
        rig.useCase.updateConfiguration(filter: .standard, enabled: [.gpu, .memoryPressure, .battery])
        let snapshot = rig.useCase.execute()
        #expect(snapshot.gpu == nil)
        #expect(snapshot.memoryPressure == nil)
        #expect(snapshot.battery == nil)
    }

    @Test("disk rate is nil on the first reading and real on the second")
    func diskRateSeedsThenMeasures() {
        let rig = Rig()
        rig.useCase.updateConfiguration(filter: .standard, enabled: [.disk])
        rig.fakes.disk.counters = DiskCounters(readBytes: 0, writeBytes: 0)
        #expect(rig.useCase.execute().disk == nil)

        rig.fakes.clock.advance(seconds: 2)
        rig.fakes.disk.counters = DiskCounters(readBytes: 4_000, writeBytes: 2_000)
        let disk = rig.useCase.execute().disk
        #expect(disk == DiskRates(readBps: 2_000, writeBps: 1_000))
    }

    @Test("thermal collector is refreshed in the background and read without blocking")
    func thermalIsNonBlocking() {
        let rig = Rig()
        rig.useCase.updateConfiguration(filter: .standard, enabled: [.thermal])
        rig.fakes.thermal.reading = ThermalReading(cpuTemperatureC: 47)
        let snapshot = rig.useCase.execute()
        #expect(rig.fakes.thermal.refreshRequests == 1)
        #expect(snapshot.thermal?.cpuTemperatureC == 47)
    }

    private var sampleBattery: BatteryReading {
        BatteryReading(
            currentPercent: 84, healthPercent: 91, cycleCount: 212,
            isCharging: false, isOnACPower: false, minutesRemaining: 210
        )
    }
}
