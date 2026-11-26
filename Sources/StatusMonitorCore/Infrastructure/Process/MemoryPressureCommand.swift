import Darwin
import Foundation

/// Runs `/usr/bin/memory_pressure -l warn`, the middle step of Extreme Clean. Blocks until the command exits or the
/// deadline passes, so it must be called from a background queue (MemoryCleanUseCase is only called from the
/// coordinator's background runner).
public final class MemoryPressureCommand: MemoryPressureRunner {
    private let executablePath: String
    private let arguments: [String]
    private let timeout: TimeInterval

    public init() {
        self.executablePath = "/usr/bin/memory_pressure"
        self.arguments = ["-l", "warn"]
        self.timeout = 30
    }

    /// Tests point this at a stand-in executable with a short deadline.
    init(executablePath: String, arguments: [String], timeout: TimeInterval) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeout = timeout
    }

    /// Returns the exit code. Returns -1 if the command could not be launched, or was killed at the deadline.
    public func run() -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
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
