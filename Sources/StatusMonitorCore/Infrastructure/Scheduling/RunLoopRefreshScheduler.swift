import Foundation

/**
 RefreshScheduling backed by a repeating Timer on the main run loop.

 Calling `schedule` replaces any previous timer, so only one cadence is active at a time.
 The timer allows 10% tolerance so the system can coalesce wakeups, which saves battery.
 */
public final class RunLoopRefreshScheduler: RefreshScheduling {
    private var timer: Timer?

    /// Creates a scheduler with no active timer.
    public init() {}

    /**
     Starts a repeating timer that runs `action` on the main run loop, replacing any previous timer.

     - Parameters:
       - interval: Seconds between firings.
       - action: Closure called on each firing.
     */
    public func schedule(every interval: TimeInterval, action: @escaping () -> Void) {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        newTimer.tolerance = interval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// Stops the active timer, if there is one.
    public func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
