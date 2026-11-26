import Foundation

/**
 Installs and removes the sudoers rule that lets the app run `/usr/sbin/purge` without a password.

 Install and uninstall are only ever started by an explicit user click. Each one shows a single administrator prompt.
 */
public protocol PurgePermissionService: AnyObject {
    /**
     Reports whether `sudo -n` can run purge right now.

     This never prompts for a password.

     - Returns: True when purge runs without a password.
     */
    func isInstalled() -> Bool

    /**
     Writes the sudoers rule after checking it with visudo.

     - Parameter user: The user name the rule grants purge to. Adapters reject names that are not allowed in a sudoers
       rule, with `PurgePermissionError.unsafeUserName`.
     - Throws: `PurgePermissionError` with the reason on failure, including a cancelled administrator prompt.
     */
    func install(forUser user: String) throws

    /**
     Removes the sudoers rule.

     - Throws: `PurgePermissionError` with the reason on failure, including a cancelled administrator prompt.
     */
    func uninstall() throws
}

/// Reasons an install or uninstall of the purge permission fails. Each case has a user-facing `errorDescription`.
public enum PurgePermissionError: LocalizedError, Equatable {
    /// The user name contains characters that are not allowed in a sudoers rule.
    case unsafeUserName
    /// `visudo` rejected the rule, so it was not installed. The associated value is the `visudo` output.
    case validationFailed(String)
    /// The administrator prompt was cancelled. Nothing was changed.
    case cancelled
    /// The system refused the change. The associated value is the output of the failed command.
    case commandFailed(String)

    /// A message that describes the failure and can be shown to the user.
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
