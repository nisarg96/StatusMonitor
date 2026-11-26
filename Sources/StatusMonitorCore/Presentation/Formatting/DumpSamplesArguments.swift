import Foundation

/// Why `--dump-samples` arguments were rejected.
public enum DumpSamplesArgumentError: Error, Equatable, Sendable {
    /// The value after the flag is not a whole number.
    case notAnInteger
    /// The value after the flag is outside `DumpSamplesArguments.range`.
    case outOfRange

    /**
     The message for stderr: the reason, then the usage line.
     */
    public var message: String {
        let reason: String
        switch self {
        case .notAnInteger:
            reason = "--dump-samples expects a whole number."
        case .outOfRange:
            reason = "--dump-samples count must be between 1 and 1000."
        }
        return "\(reason)\n\(DumpSamplesArguments.usage)"
    }
}

/// Parses `--dump-samples <count>` from the process arguments.
public enum DumpSamplesArguments {
    /// The command-line flag that selects the sample dump.
    public static let flag = "--dump-samples"
    /// The sample count used when the flag has no value after it.
    public static let defaultCount = 10
    /// The valid sample counts.
    public static let range = 1...1000
    /// The usage line printed with argument errors.
    public static let usage = "Usage: StatusMonitor --dump-samples <count>   (count: 1...1000)"

    /**
     Parses the sample count from the process arguments.

     A bare flag with no value uses `defaultCount`.

     - Parameters:
       - arguments: The process arguments, including the program name.
     - Returns: `.success(nil)` when the flag is absent, `.success(defaultCount)` when no value follows it,
       `.success(count)` for a count in `range`, and `.failure` for a non-integer or out-of-range value.
     */
    public static func parse(_ arguments: [String]) -> Result<Int?, DumpSamplesArgumentError> {
        guard let index = arguments.firstIndex(of: flag) else {
            return .success(nil)
        }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return .success(defaultCount)
        }
        guard let count = Int(arguments[valueIndex]) else {
            return .failure(.notAnInteger)
        }
        guard range.contains(count) else {
            return .failure(.outOfRange)
        }
        return .success(count)
    }
}
