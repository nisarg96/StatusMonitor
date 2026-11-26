import Testing
@testable import StatusMonitorCore

@Suite("CapabilityProbe")
struct CapabilityProbeTests {
    @Test("a Mac that provides everything reports every optional collector")
    func everythingAvailable() {
        let fakes = FakeSources()
        fakes.gpu.reading = GPUReading(utilizationPercent: 1)
        fakes.pressure.level = .normal
        fakes.disk.counters = DiskCounters(readBytes: 0, writeBytes: 0)
        fakes.battery.reading = BatteryReading(
            currentPercent: 50, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        fakes.thermal.probeResult = true

        let caps = CapabilityProbe(sources: fakes.sources).run()
        #expect(caps.available == Set(CollectorKind.allCases))
    }

    @Test("a desktop Mac with no battery and no GPU telemetry hides those sections")
    func desktopWithoutBattery() {
        let fakes = FakeSources()
        fakes.pressure.level = .normal
        fakes.disk.counters = DiskCounters(readBytes: 0, writeBytes: 0)
        fakes.thermal.probeResult = true

        let caps = CapabilityProbe(sources: fakes.sources).run()
        #expect(!caps.supports(.battery))
        #expect(!caps.supports(.gpu))
        #expect(caps.supports(.thermal))
    }

    @Test("a fanless Mac with a readable temperature still reports thermal")
    func fanlessStillThermal() {
        let fakes = FakeSources()
        fakes.thermal.probeResult = true
        fakes.thermal.reading = ThermalReading(cpuTemperatureC: 42, fans: [])
        #expect(CapabilityProbe(sources: fakes.sources).run().supports(.thermal))
    }

    @Test("a failing SMC probe hides the thermal section and nothing else")
    func smcFailureIsolated() {
        let fakes = FakeSources()
        fakes.thermal.probeResult = false
        fakes.pressure.level = .warning
        let caps = CapabilityProbe(sources: fakes.sources).run()
        #expect(!caps.supports(.thermal))
        #expect(caps.supports(.memoryPressure))
    }
}
