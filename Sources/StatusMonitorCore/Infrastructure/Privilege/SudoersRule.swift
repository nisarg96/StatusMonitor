import Foundation

/**
 Builds the sudoers rule that the installer writes, and checks user names for it.

 Pure, so the exact text is testable. The rule permits one command with no arguments, with NOPASSWD,
 for the named user only.
 */
public enum SudoersRule {
    /// Absolute path of the sudoers drop-in file that the installer writes.
    public static let installPath = "/etc/sudoers.d/statusmonitor-purge"

    /**
     Builds the sudoers line that grants one user the purge command.

     Produces `<user> ALL=(root) NOPASSWD: /usr/sbin/purge ""`. The `""` means no arguments; a bare
     `/usr/sbin/purge` would allow any arguments. The line has no trailing newline.

     - Parameters:
       - user: The login name the rule applies to.
     - Returns: The sudoers rule text.
     */
    public static func line(forUser user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: /usr/sbin/purge \"\""
    }

    /**
     Reports whether a user name is non-empty and uses only letters, digits, `_`, `-` and `.`.

     Letters and digits here include non-ASCII characters. The installer applies the stricter ASCII-only check.

     - Parameters:
       - user: The candidate login name.
     - Returns: True when the name is safe to place in a sudoers rule.
     */
    public static func isSafeUserName(_ user: String) -> Bool {
        !user.isEmpty && user.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
    }
}
