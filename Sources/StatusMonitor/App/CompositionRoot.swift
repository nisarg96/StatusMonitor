import Foundation
import StatusMonitorCore

/// Composition root: the only place that chooses concrete adapters.
/// Everything above it depends on protocols, which keeps the core testable.
@MainActor
final class CompositionRoot {
    let settings: SettingsViewModel
    let monitor: MonitorViewModel
    let purge: PurgePermissionViewModel
    /// Manual Clean controls. Built from the same use case as Auto Clean.
    let memoryClean: MemoryCleanViewModel

    /// Adapters for the headless `--dump-samples` mode. Chosen here so no other file in the executable builds them.
    nonisolated static func sampleDumpDependencies(
        defaults: UserDefaults = .standard
    ) -> (sources: MetricSources, settings: MetricSettings) {
        (LiveMetricSources.make(), UserDefaultsSettingsRepository(defaults: defaults).load())
    }

    /// The Clean now buttons run the shared use case. Built outside the main actor, because the view model runs
    /// the clean on a background queue.
    nonisolated static func manualClean(_ useCase: MemoryCleanUseCase) -> (CleanPreset) -> CleanOutcome {
        { preset in useCase.clean(preset, trigger: "manual") }
    }

    /// `snapshot` is the `--snapshot` developer flag. The root is wired the same way, except that no Auto Clean
    /// coordinator is built (so a refresh cannot start a clean) and the purge row never reaches the installer.
    init(defaults: UserDefaults = .standard, snapshot: Bool = false) {
        let settings = SettingsViewModel(
            repository: UserDefaultsSettingsRepository(defaults: defaults),
            loginItem: SMAppLoginItemService()
        )
        let sources = LiveMetricSources.make()
        // One executor for the app. Auto Clean and the installer share its availability cache, so an install is seen
        // at once.
        let purgeExecutor = SudoersPurgeExecutor()
        // Auto Clean: the same Standard Clean the user can press, triggered by the threshold.
        let remediationStore = UserDefaultsRemediationStore(defaults: defaults)
        let cleanUseCase = MemoryCleanUseCase(
            purge: purgeExecutor,
            pressure: MemoryPressureCommand(),
            memory: MachAvailableMemorySource(),
            log: FileRemediationLog(),
            recordClean: { remediationStore.lastCleanAt = $0 }
        )
        let autoClean: AutoCleanCoordinator? = snapshot ? nil : AutoCleanCoordinator(
            purge: purgeExecutor,
            clean: cleanUseCase,
            lastCleanAt: { remediationStore.lastCleanAt },
            recordClean: { remediationStore.lastCleanAt = $0 },
            monotonic: SystemMonotonicClock(),
            invalidateHelperCache: { purgeExecutor.invalidateAvailability() }
        )
        // Check the helper now, off the main thread, so the first due tick already has an answer.
        autoClean?.primeAvailability()

        let monitor = MonitorViewModel(
            useCase: SampleSystemMetricsUseCase(sources: sources),
            settings: settings,
            scheduler: RunLoopRefreshScheduler(),
            autoClean: autoClean,
            trafficStore: UserDefaultsDailyTrafficStore(defaults: defaults)
        )
        self.settings = settings
        self.monitor = monitor
        // Snapshot mode: the runner never runs the work, so the purge row's onAppear check never reaches the installer.
        let purgeRunner: PurgePermissionViewModel.Runner = snapshot
            ? { _, _ in } : PurgePermissionViewModel.backgroundRunner
        self.purge = PurgePermissionViewModel(
            service: SudoersInstaller(executor: purgeExecutor),
            userName: NSUserName(),
            runner: purgeRunner
        )
        self.memoryClean = MemoryCleanViewModel(clean: Self.manualClean(cleanUseCase))

        // The probe may open the SMC and enumerate sensors, so it runs off the main thread.
        // Its result is applied back on the main thread.
        let probe = CapabilityProbe(sources: sources)
        DispatchQueue.global(qos: .utility).async {
            let capabilities = probe.run()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    monitor.applyCapabilities(capabilities)
                }
            }
        }
    }
}
