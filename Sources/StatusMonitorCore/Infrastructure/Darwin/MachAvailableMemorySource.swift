import Darwin

/**
 Reads available RAM with `host_statistics64`, using `AvailableMemoryCalculator`.

 Available = free + inactive + purgeable pages. Returns nil when the kernel call fails, so a clean reports
 "unmeasured" instead of a guessed number.
 */
public struct MachAvailableMemorySource: AvailableMemorySource {
    /// Creates a source. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Reads available RAM in bytes.

     The page count is multiplied by the system page size.

     - Returns: Available bytes, or nil when the kernel call fails.
     */
    public func readAvailableBytes() -> UInt64? {
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

        return AvailableMemoryCalculator.availableBytes(
            freePages: UInt64(stats.free_count),
            inactivePages: UInt64(stats.inactive_count),
            purgeablePages: UInt64(stats.purgeable_count),
            pageSize: UInt64(getpagesize())
        )
    }
}
