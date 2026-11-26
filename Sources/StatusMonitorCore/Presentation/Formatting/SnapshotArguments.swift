import Foundation

/// Why `--snapshot` arguments were rejected.
public enum SnapshotArgumentError: Error, Equatable, Sendable {
    /// No usable folder follows the flag: none is given, or it is empty or another flag.
    case missingFolder

    /**
     The message for stderr: the reason, then the usage line.
     */
    public var message: String {
        "--snapshot expects a folder to write the PNG files into.\n\(SnapshotArguments.usage)"
    }
}

/// Parses `--snapshot <folder>` from the process arguments.
public enum SnapshotArguments {
    /// The command-line flag that selects snapshot output.
    public static let flag = "--snapshot"
    /// The usage line printed with argument errors.
    public static let usage = "Usage: StatusMonitor --snapshot <folder>"

    /**
     Parses the output folder from the process arguments.

     A flag cannot be a folder.

     - Parameters:
       - arguments: The process arguments, including the program name.
     - Returns: `.success(nil)` when the flag is absent, `.success(folder)` when a folder follows it, and `.failure`
       when the folder is missing, empty, or another flag.
     */
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
