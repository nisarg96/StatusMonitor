import Darwin
import Foundation

/**
 Runs `/usr/bin/memory_pressure -l warn`, the middle step of Extreme Clean.

 Blocks until the command exits or the deadline passes, so it must be called from a background queue.
 `MemoryCleanUseCase` is only called from the coordinator's background runner.
 */
public final class MemoryPressureCommand: MemoryPressureRunner {
    private let executablePath: String
    private let arguments: [String]
    private let timeout: TimeInterval

    /// Creates a command that runs `memory_pressure -l warn` with a 30-second deadline.
    public init() {
        self.executablePath = "/usr/bin/memory_pressure"
        self.arguments = ["-l", "warn"]
        self.timeout = 30
    }

    /**
     Creates a command that runs a given executable, so tests can use a stand-in with a short deadline.

     - Parameters:
       - executablePath: Absolute path of the executable.
       - arguments: Command-line arguments.
       - timeout: Seconds before the process is stopped.
     */
    init(executablePath: String, arguments: [String], timeout: TimeInterval) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeout = timeout
    }

    /**
     Runs the command and waits for it, up to the deadline.

     At the deadline the child gets SIGTERM, then SIGKILL two seconds later if it has not exited. The termination
     handler is set before launch, so an exit that happens at once is not missed.

     - Returns: The exit code, or -1 if the command could not be launched or was killed at the deadline.
     */
    public func run() -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
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
