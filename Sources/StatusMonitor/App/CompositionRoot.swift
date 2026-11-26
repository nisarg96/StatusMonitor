import Foundation
import StatusMonitorCore

/**
 The composition root: the only place that chooses concrete adapters.

 Everything above it depends on protocols, which keeps the core testable.
 */
@MainActor
final class CompositionRoot {
    /// The settings view model, shared by the status bar, the popover and the Settings window.
    let settings: SettingsViewModel
    /// The monitor that samples the system and publishes the readings.
    let monitor: MonitorViewModel
    /// The administrator approval state for purge.
    let purge: PurgePermissionViewModel
    /// Manual Clean controls. Built from the same use case as Auto Clean.
    let memoryClean: MemoryCleanViewModel
    /// Stored clean state, including the launch-time purge prompt's "Not now" choice.
    let remediationStore: UserDefaultsRemediationStore

    /**
     Creates the metric sources and settings for the headless `--dump-samples` mode.

     The adapters are chosen here, so no other file in the executable builds them.

     - Parameter defaults: The defaults store the settings are read from.
     - Returns: The metric sources and the settings loaded from `defaults`.
     */
    nonisolated static func sampleDumpDependencies(
        defaults: UserDefaults = .standard
    ) -> (sources: MetricSources, settings: MetricSettings) {
        (LiveMetricSources.make(), UserDefaultsSettingsRepository(defaults: defaults).load())
    }

    /**
     Returns the action for the Clean now buttons. It runs the shared use case with the "manual" trigger.

     It is built outside the main actor, because the view model runs the clean on a background queue.

     - Parameter useCase: The clean use case that Auto Clean also uses.
     - Returns: A function that runs the clean for a preset and returns its outcome.
     */
    nonisolated static func manualClean(_ useCase: MemoryCleanUseCase) -> (CleanPreset) -> CleanOutcome {
        { preset in useCase.clean(preset, trigger: "manual") }
    }

    /**
     Returns the purge row's starting state.

     In snapshot mode this runs the read-only check once, so the row shows the real state. The check runs `sudo -n -l`,
     which never prompts and never runs purge. It blocks, which is fine because no window is open. Outside snapshot mode
     the check is not run, and the row starts as not installed and refreshes when it appears.

     - Parameters:
       - service: The purge permission service. Only its read-only check is used here.
       - snapshot: True for the `--snapshot` developer flag.
     - Returns: `.installed` or `.notInstalled`.
     */
    static func purgeInitialState(
        _ service: PurgePermissionService, snapshot: Bool
    ) -> PurgePermissionViewModel.State {
        snapshot && service.isInstalled() ? .installed : .notInstalled
    }

    /**
     Wires the view models, adapters and background work for the app or for a snapshot.

     Auto Clean runs the same Standard Clean that the user can press, triggered by the threshold. One executor is
     shared by Auto Clean and the installer, so an install is seen at once through their common availability cache.

     In snapshot mode no Auto Clean coordinator is built, so a refresh cannot start a clean. The purge runner also does
     nothing, so the purge row's onAppear check never reaches the installer. Instead, the snapshot reads the purge state
     once, with the read-only check, before the row is built.

     The helper is checked at startup, off the main thread, so the first due tick already has an answer. The capability
     probe may open the SMC and enumerate sensors, so it also runs off the main thread, and its result is applied back
     on the main thread.

     - Parameter defaults: The defaults store for settings, daily traffic and the remediation log.
     - Parameter snapshot: True for the `--snapshot` developer flag.
     */
    init(defaults: UserDefaults = .standard, snapshot: Bool = false) {
        let settings = SettingsViewModel(
            repository: UserDefaultsSettingsRepository(defaults: defaults),
            loginItem: SMAppLoginItemService()
        )
        let sources = LiveMetricSources.make()
        let purgeExecutor = SudoersPurgeExecutor()
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
        self.remediationStore = remediationStore
        let purgeService = SudoersInstaller(executor: purgeExecutor)
        let purgeRunner: PurgePermissionViewModel.Runner = snapshot
            ? { _, _ in } : PurgePermissionViewModel.backgroundRunner
        self.purge = PurgePermissionViewModel(
            service: purgeService, userName: NSUserName(), runner: purgeRunner,
            initialState: Self.purgeInitialState(purgeService, snapshot: snapshot)
        )
        self.memoryClean = MemoryCleanViewModel(clean: Self.manualClean(cleanUseCase))

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
