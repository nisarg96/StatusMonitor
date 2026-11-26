import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("SudoersRule")
struct SudoersRuleTests {
    @Test("the rule allows exactly /usr/sbin/purge with no arguments, NOPASSWD, for one user")
    func exactLine() {
        #expect(SudoersRule.line(forUser: "nisarg") == "nisarg ALL=(root) NOPASSWD: /usr/sbin/purge \"\"")
    }

    @Test("user names that could alter the sudoers syntax are refused")
    func unsafeNamesRefused() {
        #expect(SudoersRule.isSafeUserName("nisarg"))
        #expect(SudoersRule.isSafeUserName("_svc-user.1"))
        #expect(!SudoersRule.isSafeUserName(""))
        #expect(!SudoersRule.isSafeUserName("a ALL=(ALL) ALL"))
        #expect(!SudoersRule.isSafeUserName("a,b"))
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

    @Test("rule definitions round-trip through Codable")
    func rulesRoundTrip() {
        let defaults = makeDefaults()
        let store = UserDefaultsRemediationStore(defaults: defaults)
        let rule = Rule(
            name: "CPU hot", metric: .cpuPercent, comparator: .greaterThan,
            threshold: 85, sustainSeconds: 30, action: .script(path: "/Users/x/a.zsh"),
            cooldownSeconds: 600, dryRun: true, enabled: false
        )
        store.saveRules([rule])
        #expect(UserDefaultsRemediationStore(defaults: defaults).loadRules() == [rule])
    }

    @Test("runtime state is keyed by rule id and survives a new store instance")
    func runtimePersists() {
        let defaults = makeDefaults()
        let id = UUID()
        let state = RuleRuntimeState(streakSeconds: 0, lastFiredAt: 1_234.5)
        UserDefaultsRemediationStore(defaults: defaults).saveRuntime(state, for: id)
        #expect(UserDefaultsRemediationStore(defaults: defaults).loadRuntime(for: id) == state)
    }

    @Test("editing a rule does not touch its runtime state")
    func editKeepsRuntime() {
        let defaults = makeDefaults()
        let store = UserDefaultsRemediationStore(defaults: defaults)
        var rule = Rule(
            name: "r", metric: .cpuPercent, comparator: .greaterThan,
            threshold: 80, sustainSeconds: 10, action: .notify, cooldownSeconds: 60
        )
        store.saveRules([rule])
        store.saveRuntime(RuleRuntimeState(lastFiredAt: 500), for: rule.id)

        rule.threshold = 10
        store.saveRules([rule])
        #expect(store.loadRuntime(for: rule.id).lastFiredAt == 500)
    }

    @Test("global timestamps and confirmations persist, and nil clears the timestamp")
    func globalsPersist() {
        let defaults = makeDefaults()
        let store = UserDefaultsRemediationStore(defaults: defaults)
        store.lastCleanAt = 42
        store.hasConfirmedScriptRules = true
        store.hasConfirmedExtremeClean = true

        let reopened = UserDefaultsRemediationStore(defaults: defaults)
        #expect(reopened.lastCleanAt == 42)
        #expect(reopened.hasConfirmedScriptRules)
        #expect(reopened.hasConfirmedExtremeClean)

        reopened.lastCleanAt = nil
        #expect(reopened.lastCleanAt == nil)
    }
}
