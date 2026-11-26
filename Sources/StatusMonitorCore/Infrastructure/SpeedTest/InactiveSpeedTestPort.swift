import Foundation

/**
 A speed test port that never contacts a service. The snapshot mode uses it, so no run can reach the network.
 */
public struct InactiveSpeedTestPort: SpeedTestPort {
    /// Creates the inactive port.
    public init() {}

    /**
     Fails at once without contacting any service.

     - Parameter progress: Never called.
     - Returns: Never returns a result.
     - Throws: `SpeedTestError.serviceUnavailable`, always.
     */
    public func run(progress: @escaping (SpeedTestProgress) -> Void) async throws -> SpeedTestResult {
        throw SpeedTestError.serviceUnavailable
    }
}
