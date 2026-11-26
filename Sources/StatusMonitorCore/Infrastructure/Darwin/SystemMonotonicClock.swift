import Dispatch

/// Monotonic clock backed by DispatchTime (mach_absolute_time under the hood). Unaffected by wall-clock changes.
public struct SystemMonotonicClock: MonotonicClock {
    public init() {}

    public func nanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}
