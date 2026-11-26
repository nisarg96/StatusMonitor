import Foundation

/**
 A progress update from a running speed test.

 Rates are decimal Mbit/s (1 Mbit = 10^6 bits), the same units as `SpeedTestResult`.
 */
public enum SpeedTestProgress: Equatable, Sendable {
    /// The latency phase has started.
    case latency
    /// The download phase is reporting a current rate in decimal Mbit/s.
    case download(Double)
    /// The upload phase is reporting a current rate in decimal Mbit/s.
    case upload(Double)
}

/**
 Runs an internet speed test against a remote service.

 The rates in the result are decimal Mbit/s (1 Mbit = 10^6 bits), not the 1024-step rates used elsewhere in the app.
 Implementations must honour task cancellation. When the calling task is cancelled, the run must stop promptly, close
 any open connections, and throw `SpeedTestError.cancelled`.
 */
public protocol SpeedTestPort {
    /**
     Runs one speed test from start to finish.

     Implementations call `progress` as each phase starts and as rates are measured. Progress is advisory, so the
     result does not depend on it.

     - Parameter progress: Receives updates as the test runs.
     - Returns: The measured result. Phases that were not measured are nil.
     - Throws: `SpeedTestError`. Throws `SpeedTestError.cancelled` when the task is cancelled.
     */
    func run(progress: @escaping (SpeedTestProgress) -> Void) async throws -> SpeedTestResult
}
