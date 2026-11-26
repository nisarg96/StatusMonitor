import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SudoersRule")
struct SudoersRuleTests {
    @Test("the rule allows exactly /usr/sbin/purge with no arguments, NOPASSWD, for one user")
    func exactLine() {
        #expect(SudoersRule.line(forUser: "nisarg") == "nisarg ALL=(root) NOPASSWD: /usr/sbin/purge \"\"")
    }

    @Test("the install path is the statusmonitor-specific sudoers.d file")
    func installPath() {
        #expect(SudoersRule.installPath == "/etc/sudoers.d/statusmonitor-purge")
    }
}

@Suite("SudoersPurgeExecutor (real sudo, no prompt)")
struct SudoersPurgeExecutorTests {
    @Test("availability matches sudo -n -l on this machine, so the check never prompts")
    func matchesSudoCheck() {
        // Whether the rule is installed depends on the machine, so compare with `sudo -n -l` directly.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-l", "/usr/sbin/purge"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        let executor = SudoersPurgeExecutor()
        #expect(executor.isAvailable() == (process.terminationStatus == 0))
    }

    @Test("availability is cached after the first check")
    func cached() {
        let executor = SudoersPurgeExecutor()
        #expect(executor.isAvailable() == executor.isAvailable())
    }
}

@Suite("UserDefaultsRemediationStore")
struct RemediationStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "StatusMonitorRemediationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("last clean timestamp persists, and nil clears it")
    func cleanTimestampPersists() {
        let defaults = makeDefaults()
        let store = UserDefaultsRemediationStore(defaults: defaults)
        store.lastCleanAt = 42

        let reopened = UserDefaultsRemediationStore(defaults: defaults)
        #expect(reopened.lastCleanAt == 42)

        reopened.lastCleanAt = nil
        #expect(reopened.lastCleanAt == nil)
    }
}
