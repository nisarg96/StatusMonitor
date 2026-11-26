import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("Battery power flow")
struct BatteryPowerTests {
    @Test("discharging: the wrapped unsigned current reads as a negative amperage")
    func dischargingWrapped() {
        // 10415 mV and -185 mA, stored as the unsigned 64-bit value the registry uses.
        let wrapped = NSNumber(value: UInt64(bitPattern: -185))
        let watts = BatteryParser.powerWatts(registry: ["Voltage": NSNumber(value: 10_415), "InstantAmperage": wrapped])
        #expect(abs((watts ?? 0) - (-1.927)) < 0.01)
    }

    @Test("charging: a positive current gives positive watts")
    func charging() {
        let watts = BatteryParser.powerWatts(
            registry: ["Voltage": NSNumber(value: 12_000), "Amperage": NSNumber(value: 2_000)])
        #expect(abs((watts ?? 0) - 24) < 0.001)
    }

    @Test("missing voltage or current gives no wattage, never zero")
    func missing() {
        #expect(BatteryParser.powerWatts(registry: ["Amperage": NSNumber(value: 500)]) == nil)
        #expect(BatteryParser.powerWatts(registry: ["Voltage": NSNumber(value: 12_000)]) == nil)
    }

    @Test("the signed watts label uses a minus sign while discharging")
    func wattsLabel() {
        #expect(Format.watts(12.4) == "+12.4 W")
        #expect(Format.watts(-1.9) == "−1.9 W")
    }

    @Test("a power flow row appears only when watts are known")
    func rowAppears() {
        var battery = BatteryReading(currentPercent: 50, healthPercent: nil, cycleCount: nil,
                                     isCharging: false, isOnACPower: false, minutesRemaining: nil)
        let snapshot = SystemSnapshot(battery: battery)
        #expect(!ReadoutBuilder.rows(for: snapshot, settings: MetricSettings()).contains { $0.id == "flow" })
        battery.powerWatts = -2.0
        let withFlow = ReadoutBuilder.rows(for: SystemSnapshot(battery: battery), settings: MetricSettings())
        #expect(withFlow.first { $0.id == "flow" }?.value == "−2.0 W")
    }
}
