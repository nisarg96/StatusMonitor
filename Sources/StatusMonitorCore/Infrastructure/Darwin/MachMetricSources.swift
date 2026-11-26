import Darwin

/**
 Reads cumulative CPU tick counters with `host_statistics(HOST_CPU_LOAD_INFO)`.

 Does not shell out to `top` or `ps`.
 */
public struct MachCPUTickSource: CPUTickSource {
    /// Creates a source. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Reads the current cumulative CPU ticks.

     The kernel tuple is ordered user, system, idle, nice. The counters are 32-bit and wrap, so callers take
     deltas with wrapping subtraction.

     - Returns: The counters, or nil when the kernel call fails.
     */
    public func readTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let capacity = Int(count)
        let kernelResult = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kernelResult == KERN_SUCCESS else { return nil }

        let ticks = info.cpu_ticks
        return CPUTicks(user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
    }
}

/**
 Reads used RAM with `host_statistics64(HOST_VM_INFO64)`.

 It uses the same definition of "used" as Activity Monitor.
 */
public struct MachMemoryUsageSource: MemoryUsageSource {
    /// Creates a source. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Reads used RAM in bytes.

     Used = app memory + wired + compressed. App memory = internal pages - purgeable pages. File-backed cache is
     excluded. The page count is multiplied by the system page size.

     - Returns: Used bytes, or nil when the kernel call fails.
     */
    public func readUsedBytes() -> UInt64? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let capacity = Int(count)
        let kernelResult = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kernelResult == KERN_SUCCESS else { return nil }

        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let appPages = internalPages > purgeable ? internalPages - purgeable : 0
        let pages = appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(getpagesize())
    }
}
