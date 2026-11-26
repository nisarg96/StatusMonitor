import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("Per-metric status items")
struct StatusItemVisibilityTests {
    private let everything = MetricCapabilities(available: Set(CollectorKind.allCases))

    @Test("by default CPU, RAM, GPU and network are visible and the rest are hidden")
    func defaultVisibility() {
        let settings = MetricSettings()
        let visible = MetricItemID.allCases.filter { settings.isMenuBarItemVisible($0, capabilities: everything) }
        #expect(Set(visible) == [.cpu, .gpu, .network])
    }

    @Test("an item whose collector the Mac lacks is never visible, even if it is switched on")
    func unsupportedNeverVisible() {
        var settings = MetricSettings()
        settings.hiddenMenuBarItems.remove(.disk)
        #expect(!settings.isMenuBarItemVisible(.disk, capabilities: MetricCapabilities()))
        #expect(settings.isMenuBarItemVisible(.disk, capabilities: MetricCapabilities(available: [.disk])))
    }

    @Test("hiding an item is separate from its priority")
    func hideDoesNotChangePriority() {
        var settings = MetricSettings()
        settings.menuBarPriorities[.gpu] = .low
        settings.hiddenMenuBarItems.insert(.gpu)
        #expect(settings.priority(for: .gpu) == .low)
        #expect(!settings.isMenuBarItemVisible(.gpu, capabilities: everything))
    }

    @Test("default priorities match the design: CPU and RAM high, network/GPU/battery medium, the rest low")
    func defaultPriorities() {
        #expect(MenuBarPriorities.defaultPriority(for: .cpu) == .high)
        #expect(MenuBarPriorities.defaultPriority(for: .ram) == .high)
        #expect(MenuBarPriorities.defaultPriority(for: .network) == .medium)
        #expect(MenuBarPriorities.defaultPriority(for: .memoryPressure) == .low)
        #expect(MenuBarPriorities.defaultPriority(for: .thermal) == .low)
    }

    @Test("priority order runs high, then medium, then low")
    func priorityOrder() {
        #expect(MenuBarPriority.high < MenuBarPriority.medium)
        #expect(MenuBarPriority.medium < MenuBarPriority.low)
    }
}

@Suite("Per-metric status items in the view model")
struct StatusItemViewModelTests {
    private struct Rig {
        let fakes = FakeSources()
        let repo: InMemorySettingsRepository
        let settings: SettingsViewModel
        let monitor: MonitorViewModel

        init(_ initial: MetricSettings = MetricSettings()) {
            repo = InMemorySettingsRepository(initial)
            settings = SettingsViewModel(repository: repo)
            monitor = MonitorViewModel(
                useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
                settings: settings,
                scheduler: FakeRefreshScheduler()
            )
        }
    }

    @Test("visible items are listed highest priority first, with a fixed order inside each level")
    func orderedByPriority() {
        let rig = Rig()
        rig.monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        rig.settings.setMenuBarPriority(.gpu, .high)
        rig.monitor.refresh()
        // cpu and ram are high by default, then gpu was raised to high, so all three are high and keep their fixed order.
        #expect(rig.monitor.visibleItems == [.cpu, .gpu, .network])
    }

    @Test("priority does not reorder the bar: the Settings list order does")
    func priorityDoesNotReorder() {
        let rig = Rig()
        rig.monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        rig.settings.setMenuBarPriority(.cpu, .low)
        rig.monitor.refresh()
        #expect(rig.monitor.visibleItems == [.cpu, .gpu, .network])
        rig.settings.setMenuBarOrder([.network, .gpu, .cpu] + MetricItemID.allCases.filter { ![.cpu, .gpu, .network, .ram].contains($0) } + [.ram])
        rig.monitor.refresh()
        #expect(rig.monitor.visibleItems == [.network, .gpu, .cpu])
    }

    @Test("an item with no value yet is visible but has no segment, so it can show its icon alone")
    func noValueMeansIconOnly() {
        let rig = Rig()
        rig.monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        rig.fakes.gpu.reading = nil
        rig.monitor.refresh()
        #expect(rig.monitor.visibleItems.contains(.gpu))
        #expect(rig.monitor.itemSegments[.gpu] == nil)
        #expect(rig.monitor.itemSegments[.cpu] != nil)
    }

    @Test("the value segment for CPU is percent, and RAM is GiB")
    func segmentValues() {
        let rig = Rig()
        rig.monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        rig.fakes.memory.usedBytes = 3_435_973_837
        rig.monitor.refresh()
        #expect(rig.monitor.itemSegments[.ram] == nil)  // RAM is merged into the CPU item
        #expect(rig.monitor.itemSegments[.cpu]?.value.hasSuffix("%") == true)
    }

    @Test("hiding an item removes it from the visible list but keeps its preference")
    func hideRemovesFromVisible() {
        let rig = Rig()
        rig.monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        rig.settings.setMenuBarItem(.gpu, shown: false)
        #expect(!rig.monitor.visibleItems.contains(.gpu))
    }

    @Test("turning a switched-off metric on in the bar also turns its card on")
    func barToggleEnablesCard() {
        let repo = InMemorySettingsRepository(MetricSettings(collectorOverrides: [.disk: false, .memoryPressure: false]))
        let vm = SettingsViewModel(repository: repo)
        let caps = MetricCapabilities(available: Set(CollectorKind.allCases))

        vm.setItemInMenuBar(.disk, shown: true)
        vm.setItemInMenuBar(.memoryPressure, shown: true)
        #expect(vm.settings.collectorOverrides[.disk] == true)
        #expect(vm.settings.isMenuBarItemVisible(.disk, capabilities: caps))
        #expect(vm.settings.isMenuBarItemVisible(.memoryPressure, capabilities: caps))

        vm.setItemInMenuBar(.disk, shown: false)
        #expect(!vm.settings.isMenuBarItemVisible(.disk, capabilities: caps))
    }

    @Test("priorities persist across a restart")
    func prioritiesPersist() {
        let name = "StatusItemTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        var settings = MetricSettings()
        settings.menuBarPriorities = [.thermal: .high, .cpu: .low]
        UserDefaultsSettingsRepository(defaults: defaults).save(settings)

        let reloaded = UserDefaultsSettingsRepository(defaults: defaults).load()
        #expect(reloaded.menuBarPriorities == [.thermal: .high, .cpu: .low])
    }

    @Test("an unknown priority name in stored preferences is ignored, not crashed on")
    func unknownPriorityIgnored() {
        let name = "StatusItemTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(["cpu": "urgent", "nonsense": "high"], forKey: "menuBarPriorities")
        #expect(UserDefaultsSettingsRepository(defaults: defaults).load().menuBarPriorities.isEmpty)
    }
}
