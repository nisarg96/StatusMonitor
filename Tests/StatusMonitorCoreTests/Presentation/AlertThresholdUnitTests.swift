import Foundation
import Testing
@testable import StatusMonitorCore

/// In-memory settings store. Keeps the last saved value so tests can read what would reach UserDefaults.
private final class MemorySettingsStore: SettingsRepository {
    var stored = MetricSettings()
    func load() -> MetricSettings { stored }
    func save(_ settings: MetricSettings) { stored = settings }
}

@Suite("Alert threshold units (network and disk are entered in MB/s)")
struct AlertThresholdUnitTests {
    /// 50 MB/s in bytes/s, written out so the expectation is typed as Double.
    private let fiftyMegabytesPerSecond: Double = 50.0 * 1024.0 * 1024.0

    @Test("entering 50 for network stores 50 * 1024 * 1024 bytes/s")
    func networkEntryStoresBytes() {
        let store = MemorySettingsStore()
        let viewModel = SettingsViewModel(repository: store)

        viewModel.setAlertDisplayValue(.network, 50)

        #expect(viewModel.settings.itemConfig(for: .network).alertAbove == fiftyMegabytesPerSecond)
        #expect(store.stored.itemConfig(for: .network).alertAbove == fiftyMegabytesPerSecond)
    }

    @Test("entering 50 for disk stores 50 * 1024 * 1024 bytes/s")
    func diskEntryStoresBytes() {
        let viewModel = SettingsViewModel(repository: MemorySettingsStore())

        viewModel.setAlertDisplayValue(.disk, 50)

        #expect(viewModel.settings.itemConfig(for: .disk).alertAbove == fiftyMegabytesPerSecond)
    }

    @Test("the field shows the stored bytes back in MB/s")
    func displayConvertsBack() {
        let viewModel = SettingsViewModel(repository: MemorySettingsStore())
        viewModel.setAlertDisplayValue(.network, 12.5)

        #expect(viewModel.alertDisplayValue(.network) == 12.5)
    }

    @Test("a new network alert defaults to 50 MB/s, shown as 50")
    func networkDefaultShowsFifty() {
        let viewModel = SettingsViewModel(repository: MemorySettingsStore())

        #expect(viewModel.alertDisplayValue(.network) == 50)
        #expect(SettingsViewModel.defaultAlert(for: .network) == 50 * 1024 * 1024)
    }

    @Test("percent and temperature thresholds are not scaled")
    func otherMetricsStayRaw() {
        let viewModel = SettingsViewModel(repository: MemorySettingsStore())

        viewModel.setAlertDisplayValue(.cpu, 85)
        #expect(viewModel.settings.itemConfig(for: .cpu).alertAbove == 85)
        #expect(viewModel.alertDisplayValue(.cpu) == 85)

        viewModel.setAlertDisplayValue(.thermal, 95)
        #expect(viewModel.settings.itemConfig(for: .thermal).alertAbove == 95)
    }
}
