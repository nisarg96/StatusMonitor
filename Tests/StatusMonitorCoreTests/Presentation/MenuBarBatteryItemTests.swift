import Testing
@testable import StatusMonitorCore

@Suite("Battery menu bar item")
struct MenuBarBatteryItemTests {
    private let batterySupported = MetricCapabilities(available: [.battery])

    @Test("turning the Battery item on also turns on its menu bar percentage")
    func showingBatteryTurnsOnMenuBarCharge() {
        let viewModel = SettingsViewModel(repository: InMemorySettingsRepository())
        viewModel.setBatteryDetail(.menuBarCharge, shown: false)
        viewModel.setItemInMenuBar(.battery, shown: true)
        #expect(viewModel.settings.isMenuBarItemVisible(.battery, capabilities: batterySupported))
        #expect(viewModel.settings.isBatteryDetailShown(.menuBarCharge))
    }

    @Test("turning the Battery item off leaves the menu bar percentage as it was")
    func hidingBatteryKeepsMenuBarCharge() {
        let viewModel = SettingsViewModel(repository: InMemorySettingsRepository())
        viewModel.setItemInMenuBar(.battery, shown: true)
        viewModel.setItemInMenuBar(.battery, shown: false)
        #expect(!viewModel.settings.isMenuBarItemVisible(.battery, capabilities: batterySupported))
        #expect(viewModel.settings.isBatteryDetailShown(.menuBarCharge))
    }
}
