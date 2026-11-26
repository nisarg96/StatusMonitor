import Darwin
import Foundation

/**
 Runs `/usr/sbin/purge` through a sudoers rule that allows exactly that command with no arguments.

 The app never prompts for a password. `sudo -n` fails immediately if the rule is not installed.
 `isAvailable()` and `purge()` block on a child process, so the caller must run them off the main thread.
 Each child is killed after a deadline, so a hung `sudo` cannot block the caller forever.
 */
public final class SudoersPurgeExecutor: PrivilegedPurgeExecutor {
    /// Absolute path to `sudo`.
    static let sudoPath = "/usr/bin/sudo"
    /// Absolute path to `purge`.
    static let purgePath = "/usr/sbin/purge"
    /// Seconds allowed for the availability check.
    static let availabilityTimeout: TimeInterval = 5
    /// Seconds allowed for one purge run.
    static let purgeTimeout: TimeInterval = 60

    /**
     Runs `sudo` with the given arguments and returns its exit code.

     - Parameters:
       - arguments: Arguments passed to `sudo`.
       - timeout: Seconds before the child is stopped.
     - Returns: The exit code, or -1 if the child could not be launched or was stopped at the deadline.
     */
    typealias Runner = (_ arguments: [String], _ timeout: TimeInterval) -> Int32

    private let runner: Runner
    private let lock = NSLock()
    /// Guarded by `lock`. `generation` changes on every invalidate, so a check that started before an install
    /// cannot store a stale answer afterwards.
    private var cachedAvailability: Bool?
    /// Guarded by `lock`. Changes on every invalidate.
    private var generation: UInt64 = 0

    /// Creates an executor that runs `sudo` as a child process.
    public init() {
        self.runner = { arguments, timeout in
            SudoersPurgeExecutor.run(executable: SudoersPurgeExecutor.sudoPath, arguments: arguments, timeout: timeout)
        }
    }

    /**
     Creates an executor with an injected runner, so tests never start a real `sudo`.

     - Parameters:
       - runner: Runs `sudo` with the given arguments and timeout.
     */
    init(runner: @escaping Runner) {
        self.runner = runner
    }

    /**
     Reports whether `sudo -n` accepts the purge rule without a password.

     Runs `sudo -n -l /usr/sbin/purge`, which checks the rule without running purge or prompting.
     The result is cached until `invalidateAvailability()` is called.

     - Returns: True when the rule is active.
     */
    public func isAvailable() -> Bool {
        lock.lock()
        if let cached = cachedAvailability {
            lock.unlock()
            return cached
        }
        let startGeneration = generation
        lock.unlock()

        let available = runner(["-n", "-l", Self.purgePath], Self.availabilityTimeout) == 0

        lock.lock()
        if generation == startGeneration {
            cachedAvailability = available
        }
        lock.unlock()
        return available
    }

    /**
     Forgets the cached availability result.

     Call after installing or removing the sudoers rule.
     */
    public func invalidateAvailability() {
        lock.lock()
        cachedAvailability = nil
        generation &+= 1
        lock.unlock()
    }

    /**
     Runs `sudo -n /usr/sbin/purge`.

     - Returns: The exit code, or -1 if the command could not be launched or timed out.
     */
    public func purge() -> Int32 {
        runner(["-n", Self.purgePath], Self.purgeTimeout)
    }

    /**
     Runs an executable and returns its exit code.

     A child that ignores SIGTERM is sent SIGKILL. The termination handler is set before launch,
     so an exit that happens at once is not missed.

     - Parameters:
       - executable: Absolute path of the executable.
       - arguments: Command-line arguments.
       - timeout: Seconds to wait before the child is stopped.
     - Returns: The exit status, or -1 if the process cannot be launched or has not exited by the deadline.
     */
    static func run(executable: String, arguments: [String], timeout: TimeInterval) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            return -1
        }
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = exited.wait(timeout: .now() + 2)
            }
            return -1
        }
        return process.terminationStatus
    }
}
