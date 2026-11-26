import Foundation

/**
 The user-facing text for a speed test outcome.
 */
public enum SpeedTestMessages {
    /// Shown when a run is refused because the last run started less than `SpeedTestViewModel.cooldownSeconds` ago.
    public static let cooldown = "Speed test is cooling down. Try again in a few seconds."

    /// The message for a service that cannot be reached or answers with an error.
    private static let unavailable = "The speed test service is unavailable right now."

    /**
     Returns the message for a run that ended with an error.

     - Parameter error: The error the run ended with. Any error that is not a `SpeedTestError` is treated as the
       service being unavailable, except `CancellationError`.
     - Returns: The message to show, or nil when the run was cancelled and the state should return to idle without one.
     */
    public static func message(for error: Error) -> String? {
        guard let speedTestError = error as? SpeedTestError else {
            return error is CancellationError ? nil : unavailable
        }
        switch speedTestError {
        case .offline:
            return "You appear to be offline."
        case .serviceUnavailable:
            return unavailable
        case .rateLimited:
            return cooldown
        case .invalidResponse:
            return "The speed test got an unexpected response."
        case .cancelled:
            return nil
        }
    }
}
