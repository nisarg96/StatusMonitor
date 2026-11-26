import Combine
import Testing
@testable import StatusMonitorCore

/// Counts how many times a view model's objectWillChange fires.
private final class ChangeCounter {
    private(set) var count = 0
    private var token: AnyCancellable?

    init(_ viewModel: SettingsViewModel) {
        token = viewModel.objectWillChange.sink { [weak self] in self?.count += 1 }
    }
}

/// Runs one change, then checks that the value it controls moved and that objectWillChange fired.
private func expectChange<Value: Equatable>(
    _ label: String,
    on viewModel: SettingsViewModel,
    read: () -> Value,
    write: () -> Void
) {
    let counter = ChangeCounter(viewModel)
    let before = read()
    write()
    #expect(read() != before, "\(label) did not change the value it controls")
    #expect(counter.count > 0, "\(label) did not fire objectWillChange")
}

/// Checks a Boolean control in both directions. Writing the opposite of the current value must change the getter.
private func expectBoolean(
    _ label: String,
    on viewModel: SettingsViewModel,
    read: () -> Bool,
    write: (Bool) -> Void
) {
    let start = read()
    expectChange(label, on: viewModel, read: read, write: { write(!start) })
    expectChange("\(label) (back)", on: viewModel, read: read, write: { write(start) })
}

@Suite("Control state")
struct ControlStateTests {
    private let everything = MetricCapabilities(available: Set(CollectorKind.allCases))

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(repository: InMemorySettingsRepository(), loginItem: FakeLoginItem())
    }

    @Test("the CPU, network and download and upload switches change their getters and publish")
    func displaySwitches() {
        let viewModel = makeViewModel()
        expectBoolean("setShowCPU", on: viewModel, read: { viewModel.settings.showCPU },
                      write: { viewModel.setShowCPU($0) })
        expectBoolean("setShowNetwork", on: viewModel, read: { viewModel.settings.showNetwork },
                      write: { viewModel.setShowNetwork($0) })
        expectBoolean("setShowDownload", on: viewModel, read: { viewModel.settings.showDownload },
                      write: { viewModel.setShowDownload($0) })
        expectBoolean("setShowUpload", on: viewModel, read: { viewModel.settings.showUpload },
                      write: { viewModel.setShowUpload($0) })
        expectBoolean("setIncludeLoopback", on: viewModel, read: { viewModel.settings.includeLoopback },
                      write: { viewModel.setIncludeLoopback($0) })
    }

    @Test("the CPU mode picker changes its getter and publishes")
    func cpuMode() {
        let viewModel = makeViewModel()
        expectChange("setCPUMode", on: viewModel, read: { viewModel.settings.cpuMode },
                     write: { viewModel.setCPUMode(.memoryGB) })
    }

    @Test("the Auto Clean switch and threshold change their getters and publish")
    func autoClean() {
        let viewModel = makeViewModel()
        expectBoolean("setAutoCleanEnabled", on: viewModel, read: { viewModel.settings.autoCleanEnabled },
                      write: { viewModel.setAutoCleanEnabled($0) })
        expectChange("setAutoCleanThresholdPercent", on: viewModel,
                     read: { viewModel.settings.autoCleanThresholdPercent },
                     write: { viewModel.setAutoCleanThresholdPercent(70) })
    }

    @Test("every menu bar item switch changes its visibility and publishes, except RAM")
    func menuBarItemSwitches() {
        let viewModel = makeViewModel()
        for item in MetricItemID.allCases where item != .ram {
            expectBoolean("setItemInMenuBar(\(item))", on: viewModel,
                          read: { viewModel.settings.isMenuBarItemVisible(item, capabilities: everything) },
                          write: { viewModel.setItemInMenuBar(item, shown: $0) })
        }
    }

    @Test("the RAM item has no switch, so setItemInMenuBar(.ram) changes nothing and publishes nothing")
    func ramHasNoSwitch() {
        let viewModel = makeViewModel()
        let counter = ChangeCounter(viewModel)
        viewModel.setItemInMenuBar(.ram, shown: true)
        #expect(!viewModel.settings.isMenuBarItemVisible(.ram, capabilities: everything))
        #expect(counter.count == 0)
    }

    @Test("every legacy menu bar item switch changes its state and publishes")
    func legacyMenuBarItemSwitches() {
        let viewModel = makeViewModel()
        for item in MenuBarItem.allCases {
            expectBoolean("setMenuBarItem(\(item))", on: viewModel,
                          read: { viewModel.settings.isMenuBarItemShown(item) },
                          write: { viewModel.setMenuBarItem(item, shown: $0) })
        }
    }

    @Test("every battery detail switch changes its state and publishes")
    func batteryDetailSwitches() {
        let viewModel = makeViewModel()
        for detail in BatteryDetail.allCases {
            expectBoolean("setBatteryDetail(\(detail))", on: viewModel,
                          read: { viewModel.settings.isBatteryDetailShown(detail) },
                          write: { viewModel.setBatteryDetail(detail, shown: $0) })
        }
    }

    @Test("every collector switch changes its state and publishes")
    func collectorSwitches() {
        let viewModel = makeViewModel()
        for kind in CollectorKind.allCases {
            expectBoolean("setCollectorEnabled(\(kind))", on: viewModel,
                          read: { viewModel.settings.isCollectorEnabled(kind, capabilities: everything) },
                          write: { viewModel.setCollectorEnabled(kind, $0) })
        }
    }

    @Test("item configuration, alert threshold and the card switch change their getters and publish")
    func itemConfiguration() {
        let viewModel = makeViewModel()
        expectBoolean("setItemConfig(hideWhenIdle)", on: viewModel,
                      read: { viewModel.settings.itemConfig(for: .cpu).hideWhenIdle },
                      write: { value in
                          var config = viewModel.settings.itemConfig(for: .cpu)
                          config.hideWhenIdle = value
                          viewModel.setItemConfig(.cpu, config)
                      })
        expectChange("setAlertDisplayValue", on: viewModel,
                     read: { viewModel.alertDisplayValue(.network) },
                     write: { viewModel.setAlertDisplayValue(.network, 12) })
    }

    @Test("priority and menu bar order change their getters and publish")
    func priorityAndOrder() {
        let viewModel = makeViewModel()
        expectChange("setMenuBarPriority", on: viewModel,
                     read: { viewModel.settings.priority(for: .cpu) },
                     write: { viewModel.setMenuBarPriority(.cpu, .low) })
        expectChange("setMenuBarOrder", on: viewModel,
                     read: { viewModel.settings.menuBarOrder },
                     write: { viewModel.setMenuBarOrder(MetricItemID.allCases.reversed()) })
    }

    @Test("appearance and the interface allow list change their getters and publish")
    func appearanceAndInterfaces() {
        let viewModel = makeViewModel()
        expectChange("setAppearance", on: viewModel,
                     read: { viewModel.settings.appearance },
                     write: { viewModel.setAppearance(.dark) })
        expectChange("interfaceText", on: viewModel,
                     read: { viewModel.settings.allowedInterfaces },
                     write: { viewModel.interfaceText = "en0, en1" })
    }

    @Test("the open at login switch changes its getter and publishes")
    func openAtLogin() {
        let viewModel = makeViewModel()
        expectBoolean("setOpensAtLogin", on: viewModel, read: { viewModel.opensAtLogin },
                      write: { viewModel.setOpensAtLogin($0) })
    }
}
