import Foundation

/// Installs the purge sudoers rule.
///
/// Install steps:
/// 1. Refuse unsafe user names, so no input can change the rule's meaning.
/// 2. Write the rule to a temporary file and check it with `visudo -cf`. A broken sudoers file can lock out sudo, so nothing is installed without a pass.
/// 3. Copy it into place as root with `install -m 0440 -o root -g wheel`, through one administrator prompt.
///
/// Uninstall removes the file the same way, also behind one administrator prompt.
public final class SudoersInstaller: PurgePermissionService {
    static let visudoPath = "/usr/sbin/visudo"
    private let executor: SudoersPurgeExecutor

    public init(executor: SudoersPurgeExecutor = SudoersPurgeExecutor()) {
        self.executor = executor
    }

    public func isInstalled() -> Bool {
        executor.invalidateAvailability()
        return executor.isAvailable()
    }

    public func install(forUser user: String) throws {
        guard SudoersRule.isSafeUserName(user) else { throw PurgePermissionError.unsafeUserName }

        let content = SudoersRule.line(forUser: user) + "\n"
        let staged = try Self.stage(content)
        defer { try? FileManager.default.removeItem(at: staged) }

        try Self.validate(staged)
        try Self.runAsAdministrator(
            "/usr/bin/install -m 0440 -o root -g wheel '\(staged.path)' '\(SudoersRule.installPath)'"
        )
        executor.invalidateAvailability()
    }

    public func uninstall() throws {
        try Self.runAsAdministrator("/bin/rm -f '\(SudoersRule.installPath)'")
        executor.invalidateAvailability()
    }

    // MARK: - Steps

    /// Writes the content to a private temporary file, readable only by this user.
    static func stage(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("statusmonitor-purge-\(UUID().uuidString).sudoers")
        try content.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }

    /// Runs `visudo -cf` on the staged file. Exit 0 means the syntax is valid.
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
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
