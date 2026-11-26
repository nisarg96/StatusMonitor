import Foundation
import StatusMonitorCore

/// Composition root: the only place that chooses concrete adapters.
/// Everything above it depends on protocols, which keeps the core testable.
@MainActor
final class CompositionRoot {
    let settings: SettingsViewModel
    let monitor: MonitorViewModel
    let purge: PurgePermissionViewModel

    init(defaults: UserDefaults = .standard) {
        let settings = SettingsViewModel(
            repository: UserDefaultsSettingsRepository(defaults: defaults),
            loginItem: SMAppLoginItemService()
        )
        let sources = LiveMetricSources.make()
        // Auto Clean: the same Standard Clean the user can press, triggered by the threshold.
        let purgeExecutor = SudoersPurgeExecutor()
        let memoryClean = MemoryCleanUseCase(
            purge: purgeExecutor,
            pressure: MemoryPressureCommand(),
            memory: MachAvailableMemorySource(),
            log: FileRemediationLog()
        )
        let remediationStore = UserDefaultsRemediationStore(defaults: defaults)
        let autoClean = AutoCleanCoordinator(
            purge: purgeExecutor,
            clean: memoryClean,
            lastCleanAt: { remediationStore.lastCleanAt },
            recordClean: { remediationStore.lastCleanAt = $0 }
        )

        let monitor = MonitorViewModel(
            useCase: SampleSystemMetricsUseCase(sources: sources),
            settings: settings,
            scheduler: RunLoopRefreshScheduler(),
            autoClean: autoClean,
            trafficStore: UserDefaultsDailyTrafficStore(defaults: defaults)
        )
        self.settings = settings
        self.monitor = monitor
        self.purge = PurgePermissionViewModel(service: SudoersInstaller(), userName: NSUserName())

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
