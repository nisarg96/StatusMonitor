import Foundation
import StatusMonitorCore

/**
 The headless diagnostic behind `StatusMonitor --speed-test`.

 It runs one speed test, waits for it on the calling thread, and prints each measurement. It contacts the speed test
 service only when this command runs, and only once.
 */
enum SpeedTestCommand {
    /// Holds the outcome of the background run until the calling thread reads it.
    private final class Outcome: @unchecked Sendable {
        var result: Result<SpeedTestResult, Error>?
    }

    /**
     Runs one speed test and prints the result, or the failure to standard error.

     - Parameter port: The port that runs the test.
     - Returns: The process exit status: 0 when a result was printed, 1 when the test failed.
     */
    static func run(port: SpeedTestPort) -> Int32 {
        let outcome = Outcome()
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                outcome.result = .success(try await port.run { _ in })
            } catch {
                outcome.result = .failure(error)
            }
            finished.signal()
        }
        finished.wait()

        switch outcome.result {
        case let .success(result)?:
            for row in SpeedTestFormat.rows(for: result) {
                print("\(row.label): \(row.value)")
            }
            return 0
        case let .failure(error)?:
            let message = SpeedTestMessages.message(for: error) ?? "The speed test was cancelled."
            FileHandle.standardError.write(Data((message + "\n").utf8))
            return 1
        case nil:
            return 1
        }
    }
}
