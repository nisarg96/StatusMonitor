import Darwin

/// Kernel-reported memory pressure via sysctl. This is the kernel's own signal, not a byte-count guess.
public struct SysctlMemoryPressureSource: MemoryPressureSource {
    public init() {}

    public func readLevel() -> MemoryPressureLevel? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0) == 0 else {
            return nil
        }
        return MemoryPressureLevel(sysctlValue: value)
    }
}
