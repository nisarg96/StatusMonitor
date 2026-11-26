import Foundation

/// Builds the sudoers line the installer writes, and checks its content. Pure, so the exact text is testable.
/// The rule permits one command with no arguments, with NOPASSWD, for the named user only.
public enum SudoersRule {
    public static let installPath = "/etc/sudoers.d/statusmonitor-purge"

    /// `<user> ALL=(root) NOPASSWD: /usr/sbin/purge ""`
    /// The `""` means "no arguments". A bare `/usr/sbin/purge` would allow any arguments.
    public static func line(forUser user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: /usr/sbin/purge \"\""
    }

    /// The installer refuses any user name that could change the rule's meaning.
    public static func isSafeUserName(_ user: String) -> Bool {
        !user.isEmpty && user.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
    }
}
