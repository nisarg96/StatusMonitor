import Combine
import Foundation

/**
 Presentation state for the speed test. The popover's Network card and the Settings Network section share one instance.

 A run awaits the port on the background executor and reports its progress back on the main actor. A run is refused
 while another is in progress, and within `cooldownSeconds` of the last run starting. Cancelling ends the run at once
 and returns to idle. Work that finishes after a cancel or a newer run is discarded.
 */
@MainActor
public final class SpeedTestViewModel: ObservableObject {
    /// The shortest gap between two runs starting, in seconds.
    public static let cooldownSeconds: Double = 10

    /// Where the speed test is now.
    @Published public private(set) var state: SpeedTestState = .idle

    private let port: SpeedTestPort
    private let clock: MonotonicClock
    private var lastStartNanoseconds: UInt64?
    private var generation = 0
    private var task: Task<Void, Never>?

    /**
     Creates the view model in the idle state.

     - Parameters:
       - port: Runs the speed test. Its work runs off the main thread.
       - clock: Supplies monotonic time for the cooldown.
     */
    public init(port: SpeedTestPort, clock: MonotonicClock) {
        self.port = port
        self.clock = clock
    }

    /// True while a run is in progress.
    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /**
     Starts one speed test.

     Does nothing while a run is in progress. A run that starts less than `cooldownSeconds` after the last one started
     is refused, and the state shows the cooldown message.
     */
    public func run() {
        guard !isRunning else { return }
        let now = clock.nanoseconds()
        if let last = lastStartNanoseconds, now < last + Self.cooldownNanoseconds {
            state = .failed(SpeedTestMessages.cooldown)
            return
        }
        lastStartNanoseconds = now
        generation += 1
        let token = generation
        state = .running(.latency)
        let port = self.port
        task = Task { [weak self] in
            do {
                let result = try await port.run { progress in
                    Task { @MainActor in self?.receive(progress, token: token) }
                }
                self?.finish(.done(result), token: token)
            } catch {
                self?.finish(error: error, token: token)
            }
        }
    }

    /**
     Cancels the run in progress and returns the state to idle. Does nothing when no run is in progress.
     */
    public func cancel() {
        guard isRunning else { return }
        generation += 1
        task?.cancel()
        task = nil
        state = .idle
    }

    private static var cooldownNanoseconds: UInt64 {
        UInt64(cooldownSeconds * 1_000_000_000)
    }

    private func receive(_ progress: SpeedTestProgress, token: Int) {
        guard token == generation, isRunning else { return }
        state = .running(progress)
    }

    private func finish(_ outcome: SpeedTestState, token: Int) {
        guard token == generation, isRunning else { return }
        state = outcome
        task = nil
    }

    private func finish(error: Error, token: Int) {
        let outcome = SpeedTestMessages.message(for: error).map(SpeedTestState.failed) ?? .idle
        finish(outcome, token: token)
    }
}
