import Foundation

/// Installs and removes the purge sudoers rule.
///
/// Install is one privileged command, run behind one administrator prompt. Root does everything itself:
/// 1. `mktemp` creates a root-owned temp file (mode 0600, created exclusively, so no symlink can be followed).
/// 2. The rule is written into that file.
/// 3. `visudo -cf` checks that exact file. A broken sudoers file can lock out sudo, so nothing is installed
///    without a pass.
/// 4. `install -m 0440 -o root -g wheel` copies that same file into place, and the temp file is removed.
///
/// No user-writable path is ever read by root, so the checked content is the content that gets installed.
public final class SudoersInstaller: PurgePermissionService {
    static let visudoPath = "/usr/sbin/visudo"
    /// Template for the root-owned temp file. The directory is root's home, which only root can write.
    static let rootTempTemplate = "/private/var/root/statusmonitor-sudoers.XXXXXX"

    private let executor: SudoersPurgeExecutor
    private let runPrivileged: (String) throws -> Void

    public init(executor: SudoersPurgeExecutor = SudoersPurgeExecutor()) {
        self.executor = executor
        self.runPrivileged = { try SudoersInstaller.runAsAdministrator($0) }
    }

    /// Tests inject a runner so no administrator prompt is shown.
    init(executor: SudoersPurgeExecutor, runPrivileged: @escaping (String) throws -> Void) {
        self.executor = executor
        self.runPrivileged = runPrivileged
    }

    public func isInstalled() -> Bool {
        executor.invalidateAvailability()
        return executor.isAvailable()
    }

    public func install(forUser user: String) throws {
        guard Self.isStrictUserName(user) else { throw PurgePermissionError.unsafeUserName }
        try runPrivileged(Self.installScript(line: SudoersRule.line(forUser: user)))
        executor.invalidateAvailability()
    }

    public func uninstall() throws {
        try runPrivileged("/bin/rm -f \(Self.shellQuoted(SudoersRule.installPath))")
        executor.invalidateAvailability()
    }

    // MARK: - Steps

    /// The one privileged command for install. Every step works on the same root-owned file, `$tmp`.
    static func installScript(line: String) -> String {
        "tmp=$(/usr/bin/mktemp \(rootTempTemplate)) || exit 1; "
            + "/usr/bin/printf '%s\\n' \(shellQuoted(line)) > \"$tmp\" && "
            + "\(visudoPath) -cf \"$tmp\" && "
            + "/usr/bin/install -m 0440 -o root -g wheel \"$tmp\" \(shellQuoted(SudoersRule.installPath)); "
            + "status=$?; /bin/rm -f \"$tmp\"; exit $status"
    }

    /// ASCII letters, digits, `_`, `-` and `.`. Anything else could change the shell command or the rule.
    static func isStrictUserName(_ user: String) -> Bool {
        let allowedPunctuation: Set<Unicode.Scalar> = ["_", "-", "."]
        return !user.isEmpty && user.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return true
            default: return allowedPunctuation.contains(scalar)
            }
        }
    }

    /// Wraps a value in single quotes for the shell, escaping any single quote inside it.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Writes the content to a private temporary file in the user's temp directory. Not used by install, which
    /// never lets root read a user-writable file. Kept for the check helpers below.
    static func stage(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("statusmonitor-purge-\(UUID().uuidString).sudoers")
        try content.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }

    /// Runs `visudo -cf` on a file. Exit 0 means the syntax is valid.
    static func validate(_ file: URL) throws {
        let result = runProcess(visudoPath, arguments: ["-cf", file.path])
        guard result.status == 0 else {
            throw PurgePermissionError.validationFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Runs a shell command as root with the standard macOS administrator prompt.
    /// Cancelling the prompt gives AppleScript error -128, which maps to `.cancelled`.
    static func runAsAdministrator(_ shellCommand: String) throws {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let result = runProcess("/usr/bin/osascript", arguments: ["-e", script])
        if result.status == 0 { return }
        if result.output.contains("-128") { throw PurgePermissionError.cancelled }
        throw PurgePermissionError.commandFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func runProcess(_ path: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        // Read before waiting, so a full pipe cannot block the child.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }
}
