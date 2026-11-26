import Foundation
import Testing
@testable import StatusMonitorCore

/// Scripted stand-in for the installer. It never touches /etc and never prompts.
final class FakePurgePermission: PurgePermissionService {
    var installed = false
    var installError: Error?
    var uninstallError: Error?
    private(set) var installCalls: [String] = []

    func isInstalled() -> Bool { installed }

    func install(forUser user: String) throws {
        installCalls.append(user)
        if let installError { throw installError }
        installed = true
    }

    func uninstall() throws {
        if let uninstallError { throw uninstallError }
        installed = false
    }
}

@Suite("SudoersInstaller checks (no privileged step)")
struct SudoersInstallerCheckTests {
    @Test("a user name with spaces or assignments is refused before anything is written")
    func unsafeUserRefused() {
        // Injected runner: this test must never reach the real administrator prompt.
        let installer = SudoersInstaller(
            executor: SudoersPurgeExecutor(runner: { _, _ in 0 }),
            runPrivileged: { _ in Issue.record("the privileged step must not run for an unsafe name") }
        )
        #expect(throws: PurgePermissionError.unsafeUserName) {
            try installer.install(forUser: "nisarg ALL=(ALL) ALL")
        }
    }

    @Test("the staged rule file is private to the user")
    func stagedFileIsPrivate() throws {
        let staged = try SudoersInstaller.stage("nisarg ALL=(root) NOPASSWD: /usr/sbin/purge \"\"\n")
        defer { try? FileManager.default.removeItem(at: staged) }
        let attributes = try FileManager.default.attributesOfItem(atPath: staged.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test("a valid rule passes visudo")
    func validRulePasses() throws {
        let staged = try SudoersInstaller.stage(SudoersRule.line(forUser: "nisarg") + "\n")
        defer { try? FileManager.default.removeItem(at: staged) }
        try SudoersInstaller.validate(staged)
    }

    @Test("a broken rule is rejected by visudo, so nothing would be installed")
    func brokenRuleRejected() throws {
        let staged = try SudoersInstaller.stage("this is not a sudoers rule\n")
        defer { try? FileManager.default.removeItem(at: staged) }
        #expect(throws: PurgePermissionError.self) {
            try SudoersInstaller.validate(staged)
        }
    }
}

@Suite("PurgePermissionViewModel")
struct PurgePermissionViewModelTests {
    private func makeViewModel(_ service: FakePurgePermission) -> PurgePermissionViewModel {
        // Synchronous runner: the work finishes before the call returns, so the test sees the final state.
        PurgePermissionViewModel(service: service, userName: "nisarg", runner: { work, done in done(work()) })
    }

    @Test("refresh reports installed or not installed, without prompting")
    func refreshReadsState() {
        let service = FakePurgePermission()
        let viewModel = makeViewModel(service)
        viewModel.refresh()
        #expect(viewModel.state == .notInstalled)
        service.installed = true
        viewModel.refresh()
        #expect(viewModel.state == .installed)
    }

    @Test("a successful install ends installed and uses the current user name")
    func installSucceeds() {
        let service = FakePurgePermission()
        let viewModel = makeViewModel(service)
        viewModel.install()
        #expect(service.installCalls == ["nisarg"])
        #expect(viewModel.state == .installed)
    }

    @Test("a cancelled prompt leaves the row not installed and says why")
    func cancelledPrompt() {
        let service = FakePurgePermission()
        service.installError = PurgePermissionError.cancelled
        let viewModel = makeViewModel(service)
        viewModel.install()
        #expect(viewModel.state == .failed(PurgePermissionError.cancelled.localizedDescription))
    }

    @Test("uninstall removes the rule")
    func uninstallRemoves() {
        let service = FakePurgePermission()
        service.installed = true
        let viewModel = makeViewModel(service)
        viewModel.uninstall()
        #expect(viewModel.state == .notInstalled)
    }
}
