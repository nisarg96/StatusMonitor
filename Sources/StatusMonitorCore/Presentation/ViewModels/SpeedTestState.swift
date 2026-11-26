import Foundation

/**
 Where a speed test is: idle, running at its latest progress, done with a result, or failed with a message.
 */
public enum SpeedTestState: Equatable, Sendable {
    /// No run is in progress and no result or failure is shown.
    case idle
    /// A run is in progress. The payload is the latest progress the port reported.
    case running(SpeedTestProgress)
    /// The last run finished with this result.
    case done(SpeedTestResult)
    /// The last run failed. The payload is the message to show.
    case failed(String)
}
