import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("UserDefaultsRemediationStore purge prompt declined flag")
struct PurgePromptDeclinedStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "StatusMonitorPurgePromptTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("the declined flag defaults to false on a fresh store")
    func defaultsToFalse() {
        let store = UserDefaultsRemediationStore(defaults: makeDefaults())
        #expect(store.purgePermissionPromptDeclined == false)
    }

    @Test("the declined flag round-trips through a reopened store, and can be cleared")
    func roundTrips() {
        let defaults = makeDefaults()
        let store = UserDefaultsRemediationStore(defaults: defaults)
        store.purgePermissionPromptDeclined = true

        let reopened = UserDefaultsRemediationStore(defaults: defaults)
        #expect(reopened.purgePermissionPromptDeclined == true)

        reopened.purgePermissionPromptDeclined = false
        #expect(reopened.purgePermissionPromptDeclined == false)
    }
}
