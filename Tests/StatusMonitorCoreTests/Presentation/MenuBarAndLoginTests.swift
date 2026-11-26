import Foundation
import Testing
@testable import StatusMonitorCore

final class FakeLoginItem: LoginItemService {
    var enabled = false
    var failure: Error?

    var isEnabled: Bool { enabled }

    func setEnabled(_ value: Bool) throws {
        if let failure { throw failure }
        enabled = value
    }
}

private struct RegistrationError: LocalizedError {
    var errorDescription: String? { "Operation not permitted" }
}

@Suite("Menu bar item defaults")
struct MenuBarItemDefaultsTests {
    private let full = SystemSnapshot(
        cpuPercent: 8, memoryUsedBytes: 3_435_973_837, downBps: 1_000, upBps: 2_000,
        gpu: GPUReading(utilizationPercent: 4),
        memoryPressure: .normal,
        disk: DiskRates(readBps: 1_000, writeBps: 1_000),
        battery: BatteryReading(currentPercent: 84, healthPercent: nil, cycleCount: nil,
                                isCharging: false, isOnACPower: false, minutesRemaining: nil),
        thermal: ThermalReading(cpuTemperatureC: 61)
    )

    @Test("by default the bar shows CPU, RAM, GPU and network only")
    func defaultBar() {
        let title = StatusTitleFormatter.title(for: full, settings: MetricSettings())
        #expect(title == "CPU 8% · RAM 3.2 GB · GPU 4% · ↓ 1000 B/s ↑ 2.0 KB/s")
    }

    @Test("memory pressure, disk, battery and temperature are hidden in the bar by default")
    func crowdedItemsHidden() {
        #expect(MenuBarItem.defaultHidden == [.memoryPressure, .disk, .battery, .thermal])
    }

    @Test("showing a hidden item adds its segment")
    func showingAddsSegment() {
        var settings = MetricSettings()
        settings.hiddenMenuBarItems.remove(.disk)
        let title = StatusTitleFormatter.title(for: full, settings: settings)
        #expect(title.contains("Disk ↓"))
    }

    @Test("in memory mode the CPU slot shows RAM, and no duplicate RAM item appears")
    func memoryModeNoDuplicate() {
        let settings = MetricSettings(cpuMode: .memoryGB)
        let title = StatusTitleFormatter.title(for: full, settings: settings)
        #expect(title.hasPrefix("RAM 3.2 GB"))
        #expect(title.components(separatedBy: "RAM").count == 2)
    }

    @Test("a hidden RAM item disappears from the bar but stays in the popover")
    func ramHiddenFromBar() {
        var settings = MetricSettings()
        settings.hiddenMenuBarItems.insert(.ram)
        #expect(!StatusTitleFormatter.title(for: full, settings: settings).contains("RAM"))
        #expect(ReadoutBuilder.rows(for: full, settings: settings).contains { $0.id == "ram" })
    }

    @Test("the settings view model toggles a menu bar item and persists it")
    func toggleAndPersist() {
        let repo = InMemorySettingsRepository()
        let vm = SettingsViewModel(repository: repo)
        vm.setMenuBarItem(.gpu, shown: false)
        #expect(repo.stored.hiddenMenuBarItems.contains(.gpu))
        vm.setMenuBarItem(.gpu, shown: true)
        #expect(!repo.stored.hiddenMenuBarItems.contains(.gpu))
    }
}

@Suite("Open at login")
struct OpenAtLoginTests {
    @Test("the toggle reflects the system's state at launch")
    func readsSystemState() {
        let login = FakeLoginItem()
        login.enabled = true
        let vm = SettingsViewModel(repository: InMemorySettingsRepository(), loginItem: login)
        #expect(vm.opensAtLogin)
    }

    @Test("turning it on registers the login item and reads the result back")
    func enable() {
        let login = FakeLoginItem()
        let vm = SettingsViewModel(repository: InMemorySettingsRepository(), loginItem: login)
        vm.setOpensAtLogin(true)
        #expect(login.enabled)
        #expect(vm.opensAtLogin)
        #expect(vm.loginItemError == nil)
    }

    @Test("a failure is shown, and the toggle shows the system's state, not the request")
    func failureShown() {
        let login = FakeLoginItem()
        login.failure = RegistrationError()
        let vm = SettingsViewModel(repository: InMemorySettingsRepository(), loginItem: login)
        vm.setOpensAtLogin(true)
        #expect(vm.opensAtLogin == false)
        #expect(vm.loginItemError?.contains("Operation not permitted") == true)
    }

    @Test("without a login item service the toggle stays off and does nothing")
    func noService() {
        let vm = SettingsViewModel(repository: InMemorySettingsRepository())
        vm.setOpensAtLogin(true)
        #expect(vm.opensAtLogin == false)
    }
}
