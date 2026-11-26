import Foundation

/**
 Installs and removes the purge sudoers rule.

 Install is one privileged command, run behind one administrator prompt. Root does everything itself:
 1. `mktemp` creates a root-owned temp file (mode 0600, created exclusively, so no symlink can be followed).
 2. The rule is written into that file.
 3. `visudo -cf` checks that exact file. A broken sudoers file can lock out sudo, so nothing is installed
    without a pass.
 4. `install -m 0440 -o root -g wheel` copies that same file into place, and the temp file is removed.

 No user-writable path is ever read by root, so the checked content is the content that gets installed.
 */
public final class SudoersInstaller: PurgePermissionService {
    /// Absolute path to `visudo`, which checks the rule before it is installed.
    static let visudoPath = "/usr/sbin/visudo"
    /// Template for the root-owned temp file. The directory is root's home, which only root can write.
    static let rootTempTemplate = "/private/var/root/statusmonitor-sudoers.XXXXXX"

    private let executor: SudoersPurgeExecutor
    private let runPrivileged: (String) throws -> Void

    /**
     Creates an installer that runs privileged commands behind the standard administrator prompt.

     - Parameters:
       - executor: Checks whether the rule is active, and is told when the rule changes.
     */
    public init(executor: SudoersPurgeExecutor = SudoersPurgeExecutor()) {
        self.executor = executor
        self.runPrivileged = { try SudoersInstaller.runAsAdministrator($0) }
    }

    /**
     Creates an installer with an injected privileged-command runner.

     Tests use this so that no administrator prompt is shown.

     - Parameters:
       - executor: Checks whether the rule is active, and is told when the rule changes.
       - runPrivileged: Runs one shell command as root and throws on failure.
     */
    init(executor: SudoersPurgeExecutor, runPrivileged: @escaping (String) throws -> Void) {
        self.executor = executor
        self.runPrivileged = runPrivileged
    }

    /**
     Reports whether the purge rule is active, without using a cached answer from before a change.

     - Returns: True when `sudo -n` can run purge without a password.
     */
    public func isInstalled() -> Bool {
        executor.invalidateAvailability()
        return executor.isAvailable()
    }

    /**
     Installs the purge rule for one user behind a single administrator prompt.

     - Parameters:
       - user: Login name to grant purge rights to. Must pass `isStrictUserName`.
     - Throws: `PurgePermissionError.unsafeUserName` for a name that fails the strict check,
       `PurgePermissionError.cancelled` when the prompt is dismissed, and
       `PurgePermissionError.commandFailed` when the privileged script fails, including when visudo rejects the rule.
     */
    public func install(forUser user: String) throws {
        guard Self.isStrictUserName(user) else { throw PurgePermissionError.unsafeUserName }
        try runPrivileged(Self.installScript(line: SudoersRule.line(forUser: user)))
        executor.invalidateAvailability()
    }

    /**
     Removes the purge rule behind a single administrator prompt.

     - Throws: `PurgePermissionError.cancelled` when the prompt is dismissed, and
       `PurgePermissionError.commandFailed` when the removal fails.
     */
    public func uninstall() throws {
        try runPrivileged("/bin/rm -f \(Self.shellQuoted(SudoersRule.installPath))")
        executor.invalidateAvailability()
    }

    // MARK: - Steps

    /**
     Builds the one privileged shell command that performs an install.

     Every step works on the same root-owned file, `$tmp`.

     - Parameters:
       - line: The sudoers rule text to write.
     - Returns: The shell command to run as root.
     */
    static func installScript(line: String) -> String {
        "tmp=$(/usr/bin/mktemp \(rootTempTemplate)) || exit 1; "
            + "/usr/bin/printf '%s\\n' \(shellQuoted(line)) > \"$tmp\" && "
            + "\(visudoPath) -cf \"$tmp\" && "
            + "/usr/bin/install -m 0440 -o root -g wheel \"$tmp\" \(shellQuoted(SudoersRule.installPath)); "
            + "status=$?; /bin/rm -f \"$tmp\"; exit $status"
    }

    /**
     Reports whether a user name uses only ASCII letters, digits, `_`, `-` and `.`.

     Anything else could change the shell command or the rule.

     - Parameters:
       - user: The candidate login name.
     - Returns: True for a non-empty name made only of those characters.
     */
    static func isStrictUserName(_ user: String) -> Bool {
        let allowedPunctuation: Set<Unicode.Scalar> = ["_", "-", "."]
        return !user.isEmpty && user.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return true
            default: return allowedPunctuation.contains(scalar)
            }
        }
    }

    /**
     Wraps a value in single quotes for the shell, escaping any single quote inside it.

     - Parameters:
       - value: The text to quote.
     - Returns: The quoted text, safe to splice into a shell command.
     */
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /**
     Runs a shell command as root with the standard macOS administrator prompt.

     The command is escaped for an AppleScript string literal before it is sent to `osascript`.

     - Parameters:
       - shellCommand: The shell command to run as root.
     - Throws: `PurgePermissionError.cancelled` when the user dismisses the prompt (AppleScript error -128), and
       `PurgePermissionError.commandFailed` for any other non-zero exit.
     */
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

    /**
     Runs a tool and captures its combined stdout and stderr.

     The output is read before the process is waited on, so a full pipe cannot block the child.

     - Parameters:
       - path: Absolute path of the executable.
       - arguments: Command-line arguments.
     - Returns: The exit status (-1 if the process could not be launched) and the decoded output.
     */
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
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }
}
