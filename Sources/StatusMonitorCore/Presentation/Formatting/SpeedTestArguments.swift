import Foundation

/// Parses the `--speed-test` diagnostic flag from the process arguments.
public enum SpeedTestArguments {
    /// The command-line flag that runs one speed test and prints the result.
    public static let flag = "--speed-test"

    /**
     Reports whether the diagnostic was requested.

     - Parameter arguments: The process arguments, including the program name.
     - Returns: True when the flag appears after the program name.
     */
    public static func isRequested(_ arguments: [String]) -> Bool {
        arguments.dropFirst().contains(flag)
    }
}
