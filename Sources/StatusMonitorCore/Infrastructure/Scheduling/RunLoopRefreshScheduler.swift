import Foundation

/// RefreshScheduling backed by a repeating Timer on the main run loop.
/// Calling `schedule` replaces any previous timer, so only one cadence is active at a time.
public final class RunLoopRefreshScheduler: RefreshScheduling {
    private var timer: Timer?

    public init() {}

    public func schedule(every interval: TimeInterval, action: @escaping () -> Void) {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        // A little tolerance lets the system coalesce wakeups, which saves battery.
        newTimer.tolerance = interval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
