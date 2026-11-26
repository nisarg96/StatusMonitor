import Foundation

/// Why `--dump-samples` arguments were rejected.
public enum DumpSamplesArgumentError: Error, Equatable, Sendable {
    case notAnInteger
    case outOfRange

    /// One-line message for stderr, including the usage line.
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
    public static let flag = "--dump-samples"
    public static let defaultCount = 10
    public static let range = 1...1000
    public static let usage = "Usage: StatusMonitor --dump-samples <count>   (count: 1...1000)"

    /// Returns `.success(nil)` when the flag is absent, `.success(n)` for a valid count,
    /// and `.failure` for a missing, non-numeric, zero, negative, or too-large value.
    public static func parse(_ arguments: [String]) -> Result<Int?, DumpSamplesArgumentError> {
        guard let index = arguments.firstIndex(of: flag) else {
            return .success(nil)
        }
        let valueIndex = arguments.index(after: index)
        // A bare flag keeps the documented default of 10 samples.
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
