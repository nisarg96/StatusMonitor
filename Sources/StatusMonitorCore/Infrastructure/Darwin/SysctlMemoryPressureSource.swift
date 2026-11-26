import Darwin

/**
 Reads the kernel's memory pressure level through sysctl.

 This is the kernel's own signal, not a byte-count estimate.
 */
public struct SysctlMemoryPressureSource: MemoryPressureSource {
    /// Creates a source. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Reads `kern.memorystatus_vm_pressure_level`.

     - Returns: The current level, or nil when the sysctl call fails or the value is not recognized.
     */
    public func readLevel() -> MemoryPressureLevel? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0) == 0 else {
            return nil
        }
        return MemoryPressureLevel(sysctlValue: value)
    }
}
