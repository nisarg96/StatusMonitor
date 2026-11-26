import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("GPUStatisticsParser")
struct GPUStatisticsParserTests {
    @Test("reads utilization and VRAM, with total = used + free")
    func fullStats() {
        let stats: [String: Any] = [
            "Device Utilization %": NSNumber(value: 37),
            "vramUsedBytes": NSNumber(value: 1_000_000_000),
            "vramFreeBytes": NSNumber(value: 3_000_000_000),
        ]
        let reading = GPUStatisticsParser.parse(stats)
        #expect(reading?.utilizationPercent == 37)
        #expect(reading?.vramUsedBytes == 1_000_000_000)
        #expect(reading?.vramTotalBytes == 4_000_000_000)
    }

    @Test("falls back to GPU Core Utilization when Device Utilization is absent")
    func fallbackKey() {
        let reading = GPUStatisticsParser.parse(["GPU Core Utilization": NSNumber(value: 12)])
        #expect(reading?.utilizationPercent == 12)
    }

    @Test("no utilization key means the GPU is unavailable (nil, not zero)")
    func noUtilizationIsNil() {
        #expect(GPUStatisticsParser.parse(["vramUsedBytes": NSNumber(value: 5)]) == nil)
    }

    @Test("an out-of-range utilization value is discarded, not rescaled")
    func outOfRangeDiscarded() {
        #expect(GPUStatisticsParser.parse(["Device Utilization %": NSNumber(value: 250_000_000)]) == nil)
    }

    @Test("VRAM is omitted unless both used and free are present")
    func partialVRAMOmitted() {
        let reading = GPUStatisticsParser.parse([
            "Device Utilization %": NSNumber(value: 5),
            "vramUsedBytes": NSNumber(value: 100),
        ])
        #expect(reading?.utilizationPercent == 5)
        #expect(reading?.vramUsedBytes == nil)
        #expect(reading?.vramTotalBytes == nil)
    }
}

@Suite("DiskStatisticsParser")
struct DiskStatisticsParserTests {
    @Test("sums read and write bytes across drivers")
    func sumsDrivers() {
        let counters = DiskStatisticsParser.counters(from: [
            ["Bytes (Read)": NSNumber(value: 100), "Bytes (Write)": NSNumber(value: 50)],
            ["Bytes (Read)": NSNumber(value: 300), "Bytes (Write)": NSNumber(value: 150)],
        ])
        #expect(counters == DiskCounters(readBytes: 400, writeBytes: 200))
    }

    @Test("no driver reporting either counter yields nil")
    func noCountersIsNil() {
        #expect(DiskStatisticsParser.counters(from: [["Other": NSNumber(value: 1)]]) == nil)
        #expect(DiskStatisticsParser.counters(from: []) == nil)
    }

    @Test("a single counter present is still reported, with the other at zero")
    func partialCounters() {
        let counters = DiskStatisticsParser.counters(from: [["Bytes (Read)": NSNumber(value: 42)]])
        #expect(counters == DiskCounters(readBytes: 42, writeBytes: 0))
    }
}

@Suite("BatteryParser")
struct BatteryParserTests {
    private let internalBattery: [String: Any] = [
        "Type": "InternalBattery",
        "Is Present": true,
        "Current Capacity": NSNumber(value: 84),
        "Max Capacity": NSNumber(value: 100),
        "Is Charging": false,
        "Power Source State": "Battery Power",
        "Time to Empty": NSNumber(value: 210),
    ]

    @Test("reads charge, power state, and time to empty while discharging")
    func dischargingReading() {
        let reading = BatteryParser.parse(source: internalBattery, registry: [:])
        #expect(reading?.currentPercent == 84)
        #expect(reading?.isCharging == false)
        #expect(reading?.isOnACPower == false)
        #expect(reading?.minutesRemaining == 210)
    }

    @Test("uses time to full while charging")
    func chargingUsesTimeToFull() {
        var source = internalBattery
        source["Is Charging"] = true
        source["Power Source State"] = "AC Power"
        source["Time to Full Charge"] = NSNumber(value: 45)
        let reading = BatteryParser.parse(source: source, registry: [:])
        #expect(reading?.isCharging == true)
        #expect(reading?.isOnACPower == true)
        #expect(reading?.minutesRemaining == 45)
    }

    @Test("a sentinel or zero time estimate is treated as unknown, not shown")
    func sentinelTimeIsNil() {
        var source = internalBattery
        source["Time to Empty"] = NSNumber(value: 65_535)
        #expect(BatteryParser.parse(source: source, registry: [:])?.minutesRemaining == nil)
        source["Time to Empty"] = NSNumber(value: 0)
        #expect(BatteryParser.parse(source: source, registry: [:])?.minutesRemaining == nil)
    }

    @Test("a non-battery power source (for example UPS) yields nil")
    func nonBatterySourceIsNil() {
        var source = internalBattery
        source["Type"] = "UPS"
        #expect(BatteryParser.parse(source: source, registry: [:]) == nil)
    }

    @Test("an absent battery (not present) yields nil")
    func notPresentIsNil() {
        var source = internalBattery
        source["Is Present"] = false
        #expect(BatteryParser.parse(source: source, registry: [:]) == nil)
    }

    @Test("health = raw max over design, from the registry")
    func healthFromRegistry() {
        let health = BatteryParser.health(registry: [
            "DesignCapacity": NSNumber(value: 6000),
            "AppleRawMaxCapacity": NSNumber(value: 5460),
        ])
        #expect(health != nil)
        #expect(abs((health ?? 0) - 91) < 0.01)
    }

    @Test("health falls back to nominal capacity when raw max is missing")
    func healthFallback() {
        let health = BatteryParser.health(registry: [
            "DesignCapacity": NSNumber(value: 1000),
            "NominalChargeCapacity": NSNumber(value: 800),
        ])
        #expect(health == 80)
    }

    @Test("health is nil without a design capacity, and never exceeds 100")
    func healthBounds() {
        #expect(BatteryParser.health(registry: ["AppleRawMaxCapacity": NSNumber(value: 5)]) == nil)
        let over = BatteryParser.health(registry: [
            "DesignCapacity": NSNumber(value: 100), "AppleRawMaxCapacity": NSNumber(value: 130),
        ])
        #expect(over == 100)
    }

    @Test("cycle count is read from the registry")
    func cycleCount() {
        let reading = BatteryParser.parse(source: internalBattery, registry: ["CycleCount": NSNumber(value: 212)])
        #expect(reading?.cycleCount == 212)
    }
}
