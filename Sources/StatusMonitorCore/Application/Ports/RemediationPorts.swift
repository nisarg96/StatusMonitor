import Foundation

/**
 Runs `/usr/sbin/purge` with root privileges.

 The adapter uses a sudoers rule and runs `sudo -n /usr/sbin/purge`. `isAvailable` must never prompt. Installation is a
 separate, user-initiated action.
 */
public protocol PrivilegedPurgeExecutor: AnyObject {
    /**
     Reports whether `sudo -n` can run purge without a password.

     This never prompts.

     - Returns: True when purge can run now without a password.
     */
    func isAvailable() -> Bool

    /**
     Runs purge once.

     - Returns: The process exit code, or -1 when the command could not be launched or timed out.
     */
    func purge() -> Int32
}

/**
 Runs `memory_pressure -l warn`.

 This is the middle step of Extreme Clean.
 */
public protocol MemoryPressureRunner: AnyObject {
    /**
     Runs the memory pressure command once.

     - Returns: The process exit code.
     */
    func run() -> Int32
}

/// Reads the memory that is available for use, in bytes, using the formula in `AvailableMemoryCalculator`.
public protocol AvailableMemorySource {
    /**
     Reads the available memory.

     - Returns: Available memory in bytes, or nil when it cannot be read.
     */
    func readAvailableBytes() -> UInt64?
}

/// Writes one line per clean attempt, including skipped attempts, to the remediation log.
public protocol RemediationLogWriter: AnyObject {
    /**
     Appends one entry to the remediation log.

     - Parameter entry: The entry to record.
     */
    func write(_ entry: RemediationLogEntry)
}

/// One line of the remediation log: when it was written and what happened.
public struct RemediationLogEntry: Equatable, Sendable {
    /// When the clean attempt was logged.
    public let timestamp: Date
    /**
     The log text.

     A skipped attempt reads `skipped: <reason> [<preset>, trigger: <trigger>]`. A clean that ran lists its total change
     in bytes, then each step's exit code and change. A missing reading is shown as `unmeasured`.
     */
    public let message: String

    /**
     Creates a log entry.

     - Parameters:
       - timestamp: When the clean attempt was logged.
       - message: The log text.
     */
    public init(timestamp: Date, message: String) {
        self.timestamp = timestamp
        self.message = message
    }
}
