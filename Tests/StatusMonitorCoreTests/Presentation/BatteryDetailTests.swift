import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("Battery detail toggles")
struct BatteryDetailTests {
    private let fullBattery = BatteryReading(
        currentPercent: 84, healthPercent: 91, cycleCount: 212,
        isCharging: false, isOnACPower: false, minutesRemaining: 134
    )

    private var snapshot: SystemSnapshot {
        SystemSnapshot(battery: fullBattery)
    }

    private var batteryOnly: MetricSettings {
        MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])
    }

    @Test("every battery detail is shown by default")
    func defaultsShowAll() {
        let settings = MetricSettings()
        for detail in BatteryDetail.allCases {
            #expect(settings.isBatteryDetailShown(detail))
        }
        let rows = ReadoutBuilder.rows(for: snapshot, settings: batteryOnly)
        #expect(rows.map(\.id) == ["batt", "health", "cycles", "power", "lpm", "time"])
    }

    @Test("Low Power Mode row reflects the system setting")
    func lowPowerModeValue() {
        var battery = fullBattery
        battery.isLowPowerMode = true
        let rows = ReadoutBuilder.rows(for: SystemSnapshot(battery: battery), settings: batteryOnly)
        #expect(rows.first { $0.id == "lpm" }?.value == "On")
        #expect(rows.first { $0.id == "lpm" }?.label == "Low Power Mode")
    }

    @Test("the menu bar percentage and the popover charge row hide independently")
    func menuBarAndPopoverIndependent() {
        var settings = batteryOnly
        settings.hiddenBatteryDetails = [.menuBarCharge]
        #expect(StatusTitleFormatter.title(for: snapshot, settings: settings) == "SM")
        #expect(ReadoutBuilder.rows(for: snapshot, settings: settings).contains { $0.id == "batt" })

        settings.hiddenBatteryDetails = [.charge]
        #expect(StatusTitleFormatter.title(for: snapshot, settings: settings) == "🔋 84%")
        #expect(!ReadoutBuilder.rows(for: snapshot, settings: settings).contains { $0.id == "batt" })
    }

    @Test("hiding one detail removes only its row")
    func hidingOneRow() {
        var settings = batteryOnly
        settings.hiddenBatteryDetails = [.health]
        let ids = ReadoutBuilder.rows(for: snapshot, settings: settings).map(\.id)
        #expect(ids == ["batt", "cycles", "power", "lpm", "time"])
    }

    @Test("hiding the menu bar percentage removes the menu bar battery segment")
    func menuBarChargeHidesSegment() {
        var settings = MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])
        #expect(StatusTitleFormatter.title(for: snapshot, settings: settings) == "🔋 84%")

        settings.hiddenBatteryDetails = [.menuBarCharge]
        #expect(StatusTitleFormatter.title(for: snapshot, settings: settings) == "SM")
    }

    @Test("hiding a non-charge detail leaves the menu bar segment alone")
    func otherDetailsKeepMenuBarSegment() {
        var settings = MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])
        settings.hiddenBatteryDetails = [.health, .cycles, .powerState, .timeRemaining]
        #expect(StatusTitleFormatter.title(for: snapshot, settings: settings) == "🔋 84%")
    }

    @Test("each battery row id maps to its own detail")
    func rowIdMapping() {
        #expect(ReadoutBuilder.batteryDetail(forRowID: "batt") == .charge)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "health") == .health)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "cycles") == .cycles)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "power") == .powerState)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "lpm") == .lowPowerMode)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "time") == .timeRemaining)
        #expect(ReadoutBuilder.batteryDetail(forRowID: "cpu") == nil)
    }

    @Test("the settings view model toggles one detail and persists it")
    func settingsViewModelPersists() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.setBatteryDetail(.cycles, shown: false)
        #expect(viewModel.settings.isBatteryDetailShown(.cycles) == false)
        #expect(repo.stored.hiddenBatteryDetails == [.cycles])

        viewModel.setBatteryDetail(.cycles, shown: true)
        #expect(viewModel.settings.isBatteryDetailShown(.cycles))
        #expect(repo.stored.hiddenBatteryDetails.isEmpty)
    }

    @Test("hidden battery details survive a restart")
    func persistsAcrossInstances() {
        let name = "BatteryDetailTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = UserDefaultsSettingsRepository(defaults: defaults)
        var settings = MetricSettings()
        settings.hiddenBatteryDetails = [.health, .timeRemaining]
        first.save(settings)

        let reloaded = UserDefaultsSettingsRepository(defaults: defaults).load()
        #expect(reloaded.hiddenBatteryDetails == [.health, .timeRemaining])
    }
}
