import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("UserDefaultsSettingsRepository network direction switches")
struct NetworkDirectionSettingsTests {
    /// A throwaway defaults suite so tests never touch the real preferences.
    private func makeDefaults() -> UserDefaults {
        let name = "StatusMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("upload and download switches default to on")
    func defaultsOn() {
        let settings = MetricSettings()
        #expect(settings.showUpload && settings.showDownload)
    }

    @Test("each switch round-trips through save and load")
    func roundTrip() {
        let combinations: [(download: Bool, upload: Bool)] = [
            (true, true), (false, true), (true, false), (false, false)
        ]
        for combination in combinations {
            let defaults = makeDefaults()
            let original = MetricSettings(showDownload: combination.download, showUpload: combination.upload)
            UserDefaultsSettingsRepository(defaults: defaults).save(original)
            let loaded = UserDefaultsSettingsRepository(defaults: defaults).load()
            #expect(loaded.showDownload == combination.download)
            #expect(loaded.showUpload == combination.upload)
            #expect(loaded == original)
        }
    }

    @Test("saved data without the switch keys loads with both directions on")
    func legacyDataLoadsOn() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsSettingsRepository.Key.showNetwork)
        let loaded = UserDefaultsSettingsRepository(defaults: defaults).load()
        #expect(loaded.showDownload)
        #expect(loaded.showUpload)
    }
}
