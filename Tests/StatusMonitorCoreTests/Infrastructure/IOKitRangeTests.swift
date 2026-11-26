import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("IOKit numeric range guards")
struct IOKitRangeTests {
    @Test("a value at or above 2^64 is rejected instead of trapping in UInt64(Double)")
    func unsignedRejectsOutOfRange() {
        #expect(IOValue.unsigned(NSNumber(value: 1e20)) == nil)
        #expect(IOValue.unsigned(NSNumber(value: 18_446_744_073_709_551_616.0)) == nil)   // exactly 2^64
    }

    @Test("values just below 2^64 still convert")
    func unsignedAcceptsLargeInRange() {
        #expect(IOValue.unsigned(NSNumber(value: 1_000_000_000_000)) == 1_000_000_000_000)
    }

    @Test("a disk counter at or above 2^64 is skipped, not a trap")
    func diskCounterOutOfRange() {
        let drivers: [[String: Any]] = [
            ["Bytes (Read)": NSNumber(value: 1e20), "Bytes (Write)": NSNumber(value: 10)]
        ]
        #expect(DiskStatisticsParser.counters(from: drivers) == DiskCounters(readBytes: 0, writeBytes: 10))
    }

    @Test("a cycle count above Int.max is dropped instead of trapping in Int(UInt64)")
    func cycleCountAboveIntMax() {
        let source: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 50, "Max Capacity": 100]
        let registry: [String: Any] = ["CycleCount": NSNumber(value: UInt64(Int.max) + 10)]
        let reading = BatteryParser.parse(source: source, registry: registry)
        #expect(reading?.cycleCount == nil)
    }

    @Test("a normal cycle count is kept")
    func cycleCountNormal() {
        let source: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 50, "Max Capacity": 100]
        let reading = BatteryParser.parse(source: source, registry: ["CycleCount": NSNumber(value: 312)])
        #expect(reading?.cycleCount == 312)
    }

    @Test("battery percent is clamped to 0...100 when the ratio is out of range")
    func batteryPercentClamped() {
        let high: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 150, "Max Capacity": 100]
        #expect(BatteryParser.parse(source: high, registry: [:])?.currentPercent == 100)

        let negative: [String: Any] = ["Type": "InternalBattery", "Current Capacity": -20, "Max Capacity": 100]
        #expect(BatteryParser.parse(source: negative, registry: [:])?.currentPercent == 0)
    }

    @Test("a tiny maximum that overflows the percent does not trap")
    func batteryPercentOverflowDoesNotTrap() {
        let source: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 5, "Max Capacity": 1e-300]
        #expect(BatteryParser.parse(source: source, registry: [:])?.currentPercent == 100)
    }
}
