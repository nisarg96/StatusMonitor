import Foundation

/**
 Reasons a speed test fails. Each case has a user-facing `errorDescription`.

 Speed test rates are decimal Mbit/s (1 Mbit = 10^6 bits), unlike the 1024-step rates used elsewhere in the app.
 */
public enum SpeedTestError: LocalizedError, Equatable, Sendable {
    /// There is no network connection, so the test could not start.
    case offline
    /// The server answered with an error, or it changed so the test can no longer use it.
    case serviceUnavailable
    /// The test was cancelled before it finished.
    case cancelled
    /// The server's response was malformed, such as a body the test cannot parse.
    case invalidResponse
    /// The server answered HTTP 429, so it asked the client to wait before trying again.
    case rateLimited

    /// A short message the user can read.
    public var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection. Connect to a network and try again."
        case .serviceUnavailable:
            return "The speed test service is unavailable right now. Try again later."
        case .cancelled:
            return "The speed test was cancelled."
        case .invalidResponse:
            return "The speed test service returned a response that could not be read. Try again later."
        case .rateLimited:
            return "The speed test service asked for a pause. Try again in a few seconds."
        }
    }
}
