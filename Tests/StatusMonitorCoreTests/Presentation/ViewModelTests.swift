import Testing
@testable import StatusMonitorCore

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    @Test("loads initial settings from the repository")
    func loadsInitial() {
        let repo = InMemorySettingsRepository(MetricSettings(cpuMode: .memoryGB))
        let viewModel = SettingsViewModel(repository: repo)
        #expect(viewModel.settings.cpuMode == .memoryGB)
    }

    @Test("each change is persisted immediately")
    func persistsChanges() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.setShowNetwork(false)
        #expect(repo.stored.showNetwork == false)
        #expect(repo.saveCount == 1)
    }

    @Test("setting an unchanged value does not write")
    func noOpWritesNothing() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.setShowCPU(true)
        #expect(repo.saveCount == 0)
    }

    @Test("interface text is parsed into the allow-list")
    func interfaceTextParsed() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.interfaceText = "en0, utun3"
        #expect(viewModel.settings.allowedInterfaces == ["en0", "utun3"])
        #expect(repo.stored.allowedInterfaces == ["en0", "utun3"])
    }

    @Test("collector toggles are recorded as explicit overrides and persisted")
    func collectorOverride() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.setCollectorEnabled(.gpu, false)
        #expect(viewModel.settings.collectorOverrides[.gpu] == false)
        #expect(repo.stored.collectorOverrides[.gpu] == false)
    }
}

@Suite("MonitorViewModel")
struct MonitorViewModelTests {
    private struct Rig {
        let fakes = FakeSources()
        let scheduler = FakeRefreshScheduler()
        let repo: InMemorySettingsRepository
        let settings: SettingsViewModel
        let monitor: MonitorViewModel

        init(_ initial: MetricSettings = MetricSettings()) {
            repo = InMemorySettingsRepository(initial)
            settings = SettingsViewModel(repository: repo)
            monitor = MonitorViewModel(
                useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
                settings: settings,
                scheduler: scheduler
            )
        }

        func supported(_ kinds: CollectorKind...) {
            monitor.applyCapabilities(MetricCapabilities(available: Set(kinds)))
        }
    }

    @Test("start schedules the closed-popover cadence and publishes a title")
    func startSchedulesClosedCadence() {
        let rig = Rig()
        rig.monitor.start()
        #expect(rig.scheduler.interval == MonitorViewModel.closedInterval)
        #expect(!rig.monitor.statusTitle.isEmpty)
    }

    @Test("opening the popover switches to the 2 s cadence")
    func popoverOpenCadence() {
        let rig = Rig()
        rig.monitor.start()
        rig.monitor.setPopoverOpen(true)
        #expect(rig.scheduler.interval == 2)
        rig.monitor.setPopoverOpen(false)
        #expect(rig.scheduler.interval == 5)
    }

    @Test("a refresh publishes the computed snapshot")
    func refreshPublishes() {
        let rig = Rig()
        rig.fakes.cpu.queued = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 50, system: 0, idle: 50, nice: 0)
        ]
        rig.monitor.refresh()
        rig.fakes.clock.advance(seconds: 2)
        rig.monitor.refresh()
        #expect(rig.monitor.snapshot.cpuPercent == 50)
        #expect(rig.monitor.statusTitle.hasPrefix("CPU 50%"))
    }

    @Test("hiding CPU updates the title immediately, without waiting for a refresh")
    func settingChangeUpdatesTitle() {
        let rig = Rig()
        rig.monitor.refresh()
        rig.settings.setShowCPU(false)
        #expect(!rig.monitor.statusTitle.contains("CPU"))
    }

    @Test("switching to memory mode updates the title immediately")
    func memoryModeUpdatesTitle() {
        let rig = Rig()
        rig.monitor.refresh()
        rig.settings.setCPUMode(.memoryGB)
        #expect(rig.monitor.statusTitle.hasPrefix("RAM "))
    }

    @Test("settings changes rebuild the interface filter")
    func settingChangeUpdatesFilter() {
        let rig = Rig()
        rig.fakes.interfaces.interfaces = [.active("en0"), .active("utun3")]
        rig.monitor.refresh()

        rig.settings.interfaceText = "utun3"
        rig.fakes.clock.advance(seconds: 1)
        rig.fakes.interfaces.interfaces = [.active("en0", rx: 9_000), .active("utun3", rx: 700)]
        rig.monitor.refresh()
        #expect(rig.monitor.snapshot.downBps == 700)
    }

    // MARK: - Capability gating

    @Test("no optional collector is read before the probe has reported")
    func noReadsBeforeProbe() {
        let rig = Rig()
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 30)
        rig.monitor.refresh()
        #expect(rig.fakes.gpu.reads == 0)
        #expect(rig.monitor.snapshot.gpu == nil)
    }

    @Test("a supported collector is enabled by default and appears in the title")
    func supportedDefaultsOn() {
        let rig = Rig()
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 30)
        rig.supported(.gpu)
        rig.monitor.refresh()
        #expect(rig.monitor.statusTitle.contains("GPU 30%"))
    }

    @Test("an unsupported collector is never read, even if the user had enabled it")
    func unsupportedNeverRead() {
        let rig = Rig(MetricSettings(collectorOverrides: [.gpu: true]))
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 30)
        rig.supported(.memoryPressure)
        rig.monitor.refresh()
        #expect(rig.fakes.gpu.reads == 0)
        #expect(!rig.monitor.statusTitle.contains("GPU"))
    }

    @Test("switching a supported collector off removes it from the title immediately")
    func disablingClearsSegment() {
        let rig = Rig()
        rig.fakes.gpu.reading = GPUReading(utilizationPercent: 30)
        rig.supported(.gpu)
        rig.monitor.refresh()
        #expect(rig.monitor.statusTitle.contains("GPU"))

        rig.settings.setCollectorEnabled(.gpu, false)
        #expect(!rig.monitor.statusTitle.contains("GPU"))
        #expect(rig.monitor.snapshot.gpu == nil)
    }

    @Test("a collector the user disabled stays off even when the Mac supports it")
    func userOverrideRespected() {
        let rig = Rig(MetricSettings(collectorOverrides: [.battery: false]))
        rig.fakes.battery.reading = BatteryReading(
            currentPercent: 70, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        rig.supported(.battery)
        rig.monitor.refresh()
        #expect(rig.fakes.battery.reads == 0)
    }
}
