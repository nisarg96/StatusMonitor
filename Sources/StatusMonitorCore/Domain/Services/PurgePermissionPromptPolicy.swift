import Foundation

/**
 Decides whether the launch-time prompt asking to install the purge permission should be shown.

 Pure: no UserDefaults, no AppKit. The caller supplies the installed state and the stored decline.
 */
public enum PurgePermissionPromptPolicy {
    /**
     Reports whether the install prompt should be shown now.

     The prompt is shown only when the rule is known to be missing and the user has not declined before. An unknown
     install state means the check has not answered yet, so nothing is asked.

     - Parameters:
       - installed: Whether the sudoers rule is installed, or nil when the check has not answered yet.
       - declinedBefore: True when the user has declined the prompt before, as stored by the remediation store.
     - Returns: True when the prompt should be shown.
     */
    public static func shouldAsk(installed: Bool?, declinedBefore: Bool) -> Bool {
        guard let installed else { return false }
        return !installed && !declinedBefore
    }
}
