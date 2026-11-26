import Foundation
import Testing
@testable import StatusMonitorCore

/// Records each privileged command instead of showing the administrator prompt.
final class RecordingPrivilegedRunner {
    private(set) var commands: [String] = []

    func run(_ command: String) throws {
        commands.append(command)
    }
}

/// Stands in for `sudo -n -l`. The exit status changes only when a test says so.
final class ScriptedSudoRunner {
    var status: Int32
    private(set) var calls = 0

    init(status: Int32) {
        self.status = status
    }

    func run(_ arguments: [String], _ timeout: TimeInterval) -> Int32 {
        calls += 1
        return status
    }
}

@Suite("SudoersInstaller privileged script")
struct SudoersInstallScriptTests {
    private static func script(forUser user: String = "nisarg") -> String {
        SudoersInstaller.installScript(line: SudoersRule.line(forUser: user))
    }

    /// Every absolute path the privileged command mentions.
    private static func absolutePaths(in command: String) -> [String] {
        let pattern = "/[A-Za-z0-9_./-]+"
        let range = NSRange(command.startIndex..., in: command)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: command, range: range).compactMap { match in
            Range(match.range, in: command).map { String(command[$0]) }
        }
    }

    @Test("no user-writable path appears anywhere in the privileged command")
    func noUserWritablePath() {
        let command = Self.script()
        #expect(!command.contains(FileManager.default.temporaryDirectory.path))
        #expect(!command.contains("/var/folders"))
        #expect(!command.contains("/Users/"))
        #expect(!command.contains("/tmp"))
        // Allowlist: system binaries, the root-only temp template, and the install target.
        let allowed = ["/usr/", "/bin/", "/private/var/root/statusmonitor-sudoers.XXXXXX", SudoersRule.installPath]
        for path in Self.absolutePaths(in: command) {
            #expect(allowed.contains { path.hasPrefix($0) }, "unexpected path in privileged command: \(path)")
        }
    }

    @Test("mktemp, visudo -cf and install act on the same temp file, in that order, in one command")
    func sameFileInOneInvocation() {
        let command = Self.script()
        let mktemp = command.range(of: "tmp=$(/usr/bin/mktemp ")
        let visudo = command.range(of: "/usr/sbin/visudo -cf \"$tmp\"")
        let installCommand = "/usr/bin/install -m 0440 -o root -g wheel \"$tmp\" '\(SudoersRule.installPath)'"
        let install = command.range(of: installCommand)
        #expect(mktemp != nil)
        #expect(visudo != nil)
        #expect(install != nil)
        if let mktemp, let visudo, let install {
            #expect(mktemp.lowerBound < visudo.lowerBound)
            #expect(visudo.lowerBound < install.lowerBound)
        }
        #expect(command.components(separatedBy: "mktemp").count == 2)
    }

    @Test("install runs exactly one privileged command, and it is the generated script")
    func oneInvocation() throws {
        let privileged = RecordingPrivilegedRunner()
        let sudo = ScriptedSudoRunner(status: 0)
        let installer = SudoersInstaller(
            executor: SudoersPurgeExecutor(runner: sudo.run),
            runPrivileged: privileged.run
        )
        try installer.install(forUser: "nisarg")
        #expect(privileged.commands == [Self.script()])
    }

    @Test("user names outside the strict character set are refused before any privileged command")
    func hostileNamesRefused() {
        let hostile = ["o'brien", "a;rm -rf /", "$HOME", "a\"b", "a`id`", "a b", "na\u{EF}ve", "a\\b", "a$(id)"]
        for user in hostile {
            #expect(!SudoersInstaller.isStrictUserName(user), "accepted \(user)")
            let privileged = RecordingPrivilegedRunner()
            let installer = SudoersInstaller(
                executor: SudoersPurgeExecutor(runner: ScriptedSudoRunner(status: 0).run),
                runPrivileged: privileged.run
            )
            #expect(throws: PurgePermissionError.unsafeUserName) {
                try installer.install(forUser: user)
            }
            #expect(privileged.commands.isEmpty)
        }
    }

    @Test("ordinary account names pass the strict check")
    func ordinaryNamesAccepted() {
        #expect(SudoersInstaller.isStrictUserName("nisarg"))
        #expect(SudoersInstaller.isStrictUserName("_svc-user.1"))
    }

    @Test("after install, availability reports true without relaunch, using the shared executor")
    func availableAfterInstall() throws {
        let sudo = ScriptedSudoRunner(status: 1)
        let executor = SudoersPurgeExecutor(runner: sudo.run)
        let installer = SudoersInstaller(
            executor: executor,
            runPrivileged: { _ in sudo.status = 0 }
        )
        #expect(executor.isAvailable() == false)
        try installer.install(forUser: "nisarg")
        #expect(executor.isAvailable() == true)
    }
}
