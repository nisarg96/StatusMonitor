import Foundation

/// Runs `/usr/bin/memory_pressure -l warn`, the middle step of Extreme Clean. Blocks until the command exits,
/// so it must be called from a background queue (MemoryCleanUseCase is only called from the coordinator's background runner).
public final class MemoryPressureCommand: MemoryPressureRunner {
    public init() {}

    /// Returns the exit code, or -1 if the command could not be launched.
    public func run() -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        process.arguments = ["-l", "warn"]
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
