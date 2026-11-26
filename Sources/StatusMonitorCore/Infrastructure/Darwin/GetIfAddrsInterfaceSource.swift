import Darwin

/**
 Reads per-interface link-layer byte counters with `getifaddrs` (AF_LINK records).

 Requires no permissions. The counters are 32-bit (`if_data`) and wrap, so callers take deltas with wrapping
 subtraction.
 */
public struct GetIfAddrsInterfaceSource: InterfaceCounterSource {
    /// Creates a source. It holds no state, so instances are interchangeable.
    public init() {}

    /**
     Reads the counters for every link-layer interface.

     - Returns: One entry per AF_LINK record, in `getifaddrs` order. Empty when `getifaddrs` fails.
     */
    public func readInterfaces() -> [InterfaceCounters] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var result: [InterfaceCounters] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let node = cursor {
            defer { cursor = node.pointee.ifa_next }

            guard let addr = node.pointee.ifa_addr,
                  Int32(addr.pointee.sa_family) == AF_LINK,
                  let raw = node.pointee.ifa_data else { continue }

            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            let flags = node.pointee.ifa_flags
            result.append(InterfaceCounters(
                name: String(cString: node.pointee.ifa_name),
                isUp: flags & UInt32(IFF_UP) != 0,
                isRunning: flags & UInt32(IFF_RUNNING) != 0,
                isLoopback: flags & UInt32(IFF_LOOPBACK) != 0,
                rxBytes: data.ifi_ibytes,
                txBytes: data.ifi_obytes
            ))
        }
        return result
    }
}
