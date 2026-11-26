import Testing
@testable import StatusMonitorCore

@Suite("SettingsItemRowState")
struct SettingsItemRowStateTests {
    private let allSupported = MetricCapabilities(available: Set(CollectorKind.allCases))

    @Test("turning showCPU off changes isShown for the CPU item")
    func showCPUChangesIsShown() {
        let shownState = SettingsItemRowState(
            item: .cpu, settings: MetricSettings(showCPU: true), capabilities: allSupported
        )
        let hiddenState = SettingsItemRowState(
            item: .cpu, settings: MetricSettings(showCPU: false), capabilities: allSupported
        )
        #expect(shownState.isShown)
        #expect(!hiddenState.isShown)
        #expect(shownState != hiddenState)
    }

    @Test("removing an item from hiddenMenuBarItems changes isShown")
    func hiddenMenuBarItemsChangesIsShown() {
        var settings = MetricSettings()
        let hidden = SettingsItemRowState(item: .disk, settings: settings, capabilities: allSupported)
        settings.hiddenMenuBarItems.remove(.disk)
        let shown = SettingsItemRowState(item: .disk, settings: settings, capabilities: allSupported)
        #expect(!hidden.isShown)
        #expect(shown.isShown)
        #expect(hidden != shown)
    }

    @Test("switching a collector off changes isShown even when the item is not hidden")
    func collectorOverrideChangesIsShown() {
        var settings = MetricSettings(hiddenMenuBarItems: [])
        let before = SettingsItemRowState(item: .thermal, settings: settings, capabilities: allSupported)
        settings.collectorOverrides[.thermal] = false
        let after = SettingsItemRowState(item: .thermal, settings: settings, capabilities: allSupported)
        #expect(before.isShown)
        #expect(!after.isShown)
        #expect(before != after)
    }

    @Test("an item whose collector the Mac lacks is unsupported and not shown")
    func unsupportedItem() {
        let settings = MetricSettings(hiddenMenuBarItems: [])
        let state = SettingsItemRowState(item: .battery, settings: settings, capabilities: MetricCapabilities())
        #expect(!state.isSupported)
        #expect(!state.isShown)
    }

    @Test("an item without a collector is always supported")
    func itemWithoutCollectorIsSupported() {
        let state = SettingsItemRowState(item: .cpu, settings: MetricSettings(), capabilities: MetricCapabilities())
        #expect(state.isSupported)
    }

    @Test("priority comes from the settings, and changing it changes the state")
    func priorityFromSettings() {
        var settings = MetricSettings()
        let before = SettingsItemRowState(item: .cpu, settings: settings, capabilities: allSupported)
        settings.menuBarPriorities[.cpu] = .low
        let after = SettingsItemRowState(item: .cpu, settings: settings, capabilities: allSupported)
        #expect(before.priority == .high)
        #expect(after.priority == .low)
        #expect(before != after)
    }

    @Test("the state follows the view model after a change through its setter")
    func followsViewModel() {
        let viewModel = SettingsViewModel(repository: InMemorySettingsRepository())
        let before = SettingsItemRowState(item: .disk, settings: viewModel.settings, capabilities: allSupported)
        viewModel.setItemInMenuBar(.disk, shown: true)
        let after = SettingsItemRowState(item: .disk, settings: viewModel.settings, capabilities: allSupported)
        #expect(!before.isShown)
        #expect(after.isShown)
        #expect(before != after)
    }
}
