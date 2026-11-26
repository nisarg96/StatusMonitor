import Foundation

/// Installs and removes the sudoers rule that lets the app run `/usr/sbin/purge` without a password.
/// Install and uninstall are only ever started by an explicit user click, and they each show one administrator prompt.
public protocol PurgePermissionService: AnyObject {
    /// True when `sudo -n` can run purge right now. Never prompts.
    func isInstalled() -> Bool
    /// Writes the rule after checking it with visudo. Throws with the reason on failure, including a cancelled prompt.
    func install(forUser user: String) throws
    /// Removes the rule. Throws with the reason on failure, including a cancelled prompt.
    func uninstall() throws
}

public enum PurgePermissionError: LocalizedError, Equatable {
    case unsafeUserName
    case validationFailed(String)
    case cancelled
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsafeUserName:
            return "The user name contains characters that are not allowed in a sudoers rule."
        case .validationFailed(let detail):
            return "The sudoers rule did not pass visudo, so it was not installed. \(detail)"
        case .cancelled:
            return "Cancelled. No change was made."
        case .commandFailed(let detail):
            return "The system refused the change. \(detail)"
        }
    }
}
