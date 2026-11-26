import Foundation

/// Runs `/usr/sbin/purge` through a sudoers rule that allows exactly that command with no arguments.
/// The app never prompts for a password. `sudo -n` fails immediately if the rule is not installed.
///
/// `isAvailable()` and `purge()` block on a child process, so the caller must run them off the main thread.
public final class SudoersPurgeExecutor: PrivilegedPurgeExecutor {
    static let sudoPath = "/usr/bin/sudo"
    static let purgePath = "/usr/sbin/purge"

    private var cachedAvailability: Bool?
    private let lock = NSLock()

    public init() {}

    public func isAvailable() -> Bool {
        lock.lock()
        if let cached = cachedAvailability {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // `sudo -n -l <cmd>` checks the rule without running the command or prompting.
        let status = Self.run(arguments: ["-n", "-l", Self.purgePath])
        let available = status == 0

        lock.lock()
        cachedAvailability = available
        lock.unlock()
        return available
    }

    /// Forgets the cached result. Call after installing or removing the sudoers rule.
    public func invalidateAvailability() {
        lock.lock()
        cachedAvailability = nil
        lock.unlock()
    }

    public func purge() -> Int32 {
        Self.run(arguments: ["-n", Self.purgePath])
    }

    /// Returns the exit code, or -1 if the process could not be launched.
    private static func run(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sudoPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
