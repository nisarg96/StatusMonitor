import Foundation

/// Why `--snapshot` arguments were rejected.
public enum SnapshotArgumentError: Error, Equatable, Sendable {
    case missingFolder

    /// One-line message for stderr, including the usage line.
    public var message: String {
        "--snapshot expects a folder to write the PNG files into.\n\(SnapshotArguments.usage)"
    }
}

/// Parses `--snapshot <folder>` from the process arguments.
public enum SnapshotArguments {
    public static let flag = "--snapshot"
    public static let usage = "Usage: StatusMonitor --snapshot <folder>"

    /// Returns `.success(nil)` when the flag is absent, `.success(folder)` when a folder follows it, and `.failure`
    /// when the folder is missing, empty, or another flag. A flag cannot be a folder.
    public static func parse(_ arguments: [String]) -> Result<String?, SnapshotArgumentError> {
        guard let index = arguments.firstIndex(of: flag) else {
            return .success(nil)
        }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return .failure(.missingFolder)
        }
        let folder = arguments[valueIndex]
        guard !folder.isEmpty, !folder.hasPrefix("--") else {
            return .failure(.missingFolder)
        }
        return .success(folder)
    }
}
