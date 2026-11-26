import Dispatch

/**
 Monotonic clock backed by `DispatchTime`.

 It uses `mach_absolute_time` under the hood, so changes to the wall clock do not affect it.
 */
public struct SystemMonotonicClock: MonotonicClock {
    /// Creates a clock. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Returns the monotonic uptime.

     Only the difference between two readings is meaningful.

     - Returns: The uptime in nanoseconds.
     */
    public func nanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}
