import Darwin

/// CPU ticks via host_statistics(HOST_CPU_LOAD_INFO). No shelling out.
public struct MachCPUTickSource: CPUTickSource {
    public init() {}

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

        // Tuple order: CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE.
        let ticks = info.cpu_ticks
        return CPUTicks(user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
    }
}

/// Used RAM via host_statistics64(HOST_VM_INFO64).
public struct MachMemoryUsageSource: MemoryUsageSource {
    public init() {}

    /// "Used" = app memory + wired + compressed, the same definition Activity Monitor uses:
    /// app memory = internal pages - purgeable pages. File-backed cache is excluded.
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
