import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("UserDefaultsSettingsRepository")
struct UserDefaultsSettingsRepositoryTests {
    /// A throwaway defaults suite so tests never touch the real preferences.
    private func makeDefaults() -> UserDefaults {
        let name = "StatusMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("empty defaults load the documented defaults")
    func emptyDefaults() {
        let repo = UserDefaultsSettingsRepository(defaults: makeDefaults())
        #expect(repo.load() == MetricSettings())
    }

    @Test("save then load round-trips every field, including collector overrides")
    func roundTrip() {
        let defaults = makeDefaults()
        let writer = UserDefaultsSettingsRepository(defaults: defaults)
        let original = MetricSettings(
            showCPU: false,
            cpuMode: .memoryGB,
            showNetwork: true,
            includeLoopback: true,
            allowedInterfaces: ["en0", "utun3"],
            collectorOverrides: [.gpu: false, .thermal: true]
        )
        writer.save(original)

        let reader = UserDefaultsSettingsRepository(defaults: defaults)
        #expect(reader.load() == original)
    }

    @Test("unknown collector names in stored preferences are ignored, not crashed on")
    func unknownCollectorIgnored() {
        let defaults = makeDefaults()
        defaults.set(
            ["gpu": false, "holographicDisplay": true],
            forKey: UserDefaultsSettingsRepository.Key.collectorOverrides)
        let loaded = UserDefaultsSettingsRepository(defaults: defaults).load()
        #expect(loaded.collectorOverrides == [.gpu: false])
    }
}

@Suite("MetricSettings")
struct MetricSettingsTests {
    @Test("defaults show CPU and network, percent mode, loopback off, no allow-list")
    func documentedDefaults() {
        let settings = MetricSettings()
        #expect(settings.showCPU && settings.showNetwork)
        #expect(settings.cpuMode == .percent)
        #expect(!settings.includeLoopback)
        #expect(settings.allowedInterfaces.isEmpty)
    }

    @Test("a supported collector with no override is enabled by default")
    func defaultsOnWhenSupported() {
        let caps = MetricCapabilities(available: [.gpu])
        #expect(MetricSettings().isCollectorEnabled(.gpu, capabilities: caps))
    }

    @Test("an unsupported collector is off regardless of the override")
    func unsupportedIsOff() {
        let caps = MetricCapabilities(available: [])
        #expect(!MetricSettings(collectorOverrides: [.gpu: true]).isCollectorEnabled(.gpu, capabilities: caps))
    }

    @Test("an explicit user override wins over the default")
    func overrideWins() {
        let caps = MetricCapabilities(available: [.battery])
        #expect(!MetricSettings(collectorOverrides: [.battery: false]).isCollectorEnabled(.battery, capabilities: caps))
    }

    @Test("enabledCollectors lists exactly the supported, not-disabled set")
    func enabledSet() {
        let caps = MetricCapabilities(available: [.gpu, .disk, .battery])
        let settings = MetricSettings(collectorOverrides: [.disk: false])
        #expect(settings.enabledCollectors(capabilities: caps) == [.gpu, .battery])
    }
}

@Suite("SystemSnapshot.retaining")
struct SnapshotRetainingTests {
    @Test("clears only the collectors that are not enabled")
    func clearsDisabled() {
        var snapshot = SystemSnapshot()
        snapshot.gpu = GPUReading(utilizationPercent: 5)
        snapshot.disk = DiskRates(readBps: 1, writeBps: 1)
        snapshot.thermal = ThermalReading(cpuTemperatureC: 40)

        let kept = snapshot.retaining([.gpu])
        #expect(kept.gpu != nil)
        #expect(kept.disk == nil)
        #expect(kept.thermal == nil)
    }
}
