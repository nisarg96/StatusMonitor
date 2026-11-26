import Foundation
@testable import StatusMonitorCore

/// What a `FakeSpeedTestPort` does when `run` is called.
enum FakeSpeedTestScript: Sendable {
    /// Returns the result at once.
    case succeed(SpeedTestResult)
    /// Throws the error at once.
    case fail(SpeedTestError)
    /// Reports each progress update, then waits until the task is cancelled and throws `cancelled`.
    case hang(progress: [SpeedTestProgress])
    /// Ignores cancellation, waits briefly, then returns the result.
    case ignoreCancellation(SpeedTestResult)
}

/// A speed test port that follows a script and counts its calls. It never touches the network.
final class FakeSpeedTestPort: SpeedTestPort, @unchecked Sendable {
    private let lock = NSLock()
    private let script: FakeSpeedTestScript
    private var calls = 0
    private var cancellations = 0
    private var returns = 0

    init(script: FakeSpeedTestScript) {
        self.script = script
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    var cancelledCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancellations
    }

    var returnedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return returns
    }

    func run(progress: @escaping (SpeedTestProgress) -> Void) async throws -> SpeedTestResult {
        lock.lock()
        calls += 1
        lock.unlock()
        switch script {
        case let .succeed(result):
            return result
        case let .fail(error):
            throw error
        case let .hang(updates):
            updates.forEach(progress)
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)
            } catch {
                lock.lock()
                cancellations += 1
                lock.unlock()
                throw SpeedTestError.cancelled
            }
            throw SpeedTestError.serviceUnavailable
        case let .ignoreCancellation(result):
            try? await Task.sleep(nanoseconds: 50_000_000)
            lock.lock()
            returns += 1
            lock.unlock()
            return result
        }
    }
}
