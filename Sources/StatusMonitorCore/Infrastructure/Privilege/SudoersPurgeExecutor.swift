import Darwin
import Foundation

/// Runs `/usr/sbin/purge` through a sudoers rule that allows exactly that command with no arguments.
/// The app never prompts for a password. `sudo -n` fails immediately if the rule is not installed.
///
/// `isAvailable()` and `purge()` block on a child process, so the caller must run them off the main thread.
/// Each child is killed after a deadline, so a hung `sudo` cannot block the caller forever.
public final class SudoersPurgeExecutor: PrivilegedPurgeExecutor {
    static let sudoPath = "/usr/bin/sudo"
    static let purgePath = "/usr/sbin/purge"
    static let availabilityTimeout: TimeInterval = 5
    static let purgeTimeout: TimeInterval = 60

    typealias Runner = (_ arguments: [String], _ timeout: TimeInterval) -> Int32

    private let runner: Runner
    private let lock = NSLock()
    /// Guarded by `lock`. `generation` changes on every invalidate, so a check that started before an install
    /// cannot store a stale answer afterwards.
    private var cachedAvailability: Bool?
    private var generation: UInt64 = 0

    public init() {
        self.runner = { arguments, timeout in
            SudoersPurgeExecutor.run(executable: SudoersPurgeExecutor.sudoPath, arguments: arguments, timeout: timeout)
        }
    }

    /// Tests inject a runner so no real `sudo` is started.
    init(runner: @escaping Runner) {
        self.runner = runner
    }

    public func isAvailable() -> Bool {
        lock.lock()
        if let cached = cachedAvailability {
            lock.unlock()
            return cached
        }
        let startGeneration = generation
        lock.unlock()

        // `sudo -n -l <cmd>` checks the rule without running the command or prompting.
        let available = runner(["-n", "-l", Self.purgePath], Self.availabilityTimeout) == 0

        lock.lock()
        if generation == startGeneration {
            cachedAvailability = available
        }
        lock.unlock()
        return available
    }

    /// Forgets the cached result. Call after installing or removing the sudoers rule.
    public func invalidateAvailability() {
        lock.lock()
        cachedAvailability = nil
        generation &+= 1
        lock.unlock()
    }

    public func purge() -> Int32 {
        runner(["-n", Self.purgePath], Self.purgeTimeout)
    }

    /// Runs the executable and returns its exit code. Returns -1 if it cannot be launched, or if it has not exited
    /// by the deadline. A child that ignores SIGTERM is sent SIGKILL.
    static func run(executable: String, arguments: [String], timeout: TimeInterval) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        // Set before run(), so an exit that happens at once is not missed.
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
