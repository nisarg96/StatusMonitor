import Foundation
import Testing
@testable import StatusMonitorCore

/// Characterization of MenuBarGlyphBuilder for memory pressure, thermal and battery, which carry the alert states.
@Suite("Menu bar glyph characterization: sensors")
struct MenuBarGlyphSensorCharacterizationTests {
    private let gib: UInt64 = 1_073_741_824

    // MARK: - Memory pressure

    @Test("memory pressure icon style carries the level for each state")
    func pressureIcon() {
        for level in [MemoryPressureLevel.normal, .warning, .critical] {
            let snapshot = SystemSnapshot(memoryPressure: level)
            #expect(glyphOf(.memoryPressure, snapshot)
                == .pressure(symbol: "gauge.with.dots.needle.50percent", level: level))
        }
    }

    @Test("memory pressure value style shows the label; alert is set for warning and critical")
    func pressureValue() {
        #expect(glyphOf(.memoryPressure, SystemSnapshot(memoryPressure: .normal), style: .value)
            == .text(symbol: "gauge.with.dots.needle.50percent", value: "Normal", alert: false))
        #expect(glyphOf(.memoryPressure, SystemSnapshot(memoryPressure: .warning), style: .value)
            == .text(symbol: "gauge.with.dots.needle.50percent", value: "Warning", alert: true))
        #expect(glyphOf(.memoryPressure, SystemSnapshot(memoryPressure: .critical), style: .value)
            == .text(symbol: "gauge.with.dots.needle.50percent", value: "Critical", alert: true))
    }

    @Test("memory pressure with no reading has no glyph in either style")
    func pressureNoReading() {
        #expect(glyphOf(.memoryPressure, SystemSnapshot()) == nil)
        #expect(glyphOf(.memoryPressure, SystemSnapshot(), style: .value) == nil)
    }

    // MARK: - Thermal

    @Test("thermal with no reading has no glyph")
    func thermalNoReading() {
        #expect(glyphOf(.thermal, SystemSnapshot(thermal: ThermalReading(cpuTemperatureC: nil))) == nil)
        #expect(glyphOf(.thermal, SystemSnapshot()) == nil)
    }

    @Test("thermal value style shows degrees Celsius with the unit, and alerts above alertAbove")
    func thermalValue() {
        let snapshot = SystemSnapshot(thermal: ThermalReading(cpuTemperatureC: 54.4))
        #expect(glyphOf(.thermal, snapshot) == .text(symbol: "thermometer.medium", value: "54°", alert: false))
        #expect(glyphOf(.thermal, snapshot, alertAbove: 50)
            == .text(symbol: "thermometer.medium", value: "54°", alert: true))
    }

    @Test("thermal ring fraction is temperature over 110, clamped to 1")
    func thermalRing() {
        let warm = SystemSnapshot(thermal: ThermalReading(cpuTemperatureC: 55))
        #expect(glyphOf(.thermal, warm, style: .ring)
            == .ring(symbol: "thermometer.medium", fraction: 0.5, value: "55°", alert: false))
        let hot = SystemSnapshot(thermal: ThermalReading(cpuTemperatureC: 120))
        #expect(glyphOf(.thermal, hot, style: .ring)
            == .ring(symbol: "thermometer.medium", fraction: 1, value: "120°", alert: false))
    }

    // MARK: - Battery

    @Test("battery with no reading or no charge percent has no glyph")
    func batteryNoReading() {
        #expect(glyphOf(.battery, SystemSnapshot()) == nil)
        #expect(glyphOf(.battery, SystemSnapshot(battery: BatteryReading(
            currentPercent: nil, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        ))) == nil)
    }

    @Test("battery value shows the charge with its level symbol, and never alerts")
    func batteryValue() {
        let battery = BatteryReading(
            currentPercent: 80, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        let snapshot = SystemSnapshot(battery: battery)
        #expect(glyphOf(.battery, snapshot) == .text(symbol: "battery.75", value: "80%", alert: false))
        #expect(glyphOf(.battery, snapshot, alertAbove: 10) == .text(symbol: "battery.75", value: "80%", alert: false))
    }

    @Test("battery while charging uses the bolt symbol")
    func batteryCharging() {
        let battery = BatteryReading(
            currentPercent: 80, healthPercent: nil, cycleCount: nil,
            isCharging: true, isOnACPower: true, minutesRemaining: nil
        )
        #expect(glyphOf(.battery, SystemSnapshot(battery: battery))
            == .text(symbol: "battery.100.bolt", value: "80%", alert: false))
    }

    @Test("battery ring uses the charge fraction")
    func batteryRing() {
        let battery = BatteryReading(
            currentPercent: 80, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        #expect(glyphOf(.battery, SystemSnapshot(battery: battery), style: .ring)
            == .ring(symbol: "battery.75", fraction: 0.8, value: "80%", alert: false))
    }
}
