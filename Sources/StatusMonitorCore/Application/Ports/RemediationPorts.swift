import Foundation

/// Runs `/usr/sbin/purge` with root privileges. Adapter: sudoers rule, `sudo -n /usr/sbin/purge`.
/// `isAvailable` must never prompt. Installation is a separate, user-initiated action.
public protocol PrivilegedPurgeExecutor: AnyObject {
    /// True when `sudo -n` can run purge without a password. Never prompts.
    func isAvailable() -> Bool
    /// Returns the process exit code.
    func purge() -> Int32
}

/// Runs `memory_pressure -l warn`. Used as the middle step of Extreme Clean.
public protocol MemoryPressureRunner: AnyObject {
    func run() -> Int32
}

/// Reports available memory in bytes, using AvailableMemoryCalculator.
public protocol AvailableMemorySource {
    func readAvailableBytes() -> UInt64?
}

/// Writes one line per clean attempt, including skips, to the remediation log.
public protocol RemediationLogWriter: AnyObject {
    func write(_ entry: RemediationLogEntry)
}

public struct RemediationLogEntry: Equatable, Sendable {
    public let timestamp: Date
    public let message: String

    public init(timestamp: Date, message: String) {
        self.timestamp = timestamp
        self.message = message
    }
}
