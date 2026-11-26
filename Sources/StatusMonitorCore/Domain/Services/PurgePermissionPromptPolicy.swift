import Foundation

/// Decides whether the launch-time prompt asking to install the purge permission should be shown.
/// Pure: no UserDefaults, no AppKit. The caller supplies the installed state and the stored decline.
public enum PurgePermissionPromptPolicy {
    /// True only when the rule is known to be missing and the user has not declined before.
    /// `installed == nil` means the check has not answered yet, so nothing is asked.
    public static func shouldAsk(installed: Bool?, declinedBefore: Bool) -> Bool {
        guard let installed else { return false }
        return !installed && !declinedBefore
    }
}
