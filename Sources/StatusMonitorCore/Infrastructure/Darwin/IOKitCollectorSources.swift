import Foundation
import IOKit
import IOKit.ps

// MARK: - IOKit helpers

/// Iterates the services matching a class name, releasing each one after use.
private func forEachService(matching className: String, _ body: (io_service_t) -> Void) {
    guard let matching = IOServiceMatching(className) else { return }
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
    defer { IOObjectRelease(iterator) }

    var service = IOIteratorNext(iterator)
    while service != 0 {
        body(service)
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }
}

/// Reads one registry property as a dictionary. Nil when the property is missing or has another type.
private func dictionaryProperty(_ service: io_service_t, _ key: String) -> [String: Any]? {
    IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [String: Any]
}

// MARK: - GPU

/// GPU utilization and VRAM from the IOAccelerator service's PerformanceStatistics.
public struct IOKitGPUSource: GPUSource {
    public init() {}

    public func read() -> GPUReading? {
        var result: GPUReading?
        forEachService(matching: "IOAccelerator") { service in
            guard result == nil,
                  let stats = dictionaryProperty(service, "PerformanceStatistics") else { return }
            result = GPUStatisticsParser.parse(stats)
        }
        return result
    }
}

// MARK: - Disk

/// Cumulative read and write bytes summed across IOBlockStorageDriver services.
/// Summing per driver instance may double-count if a virtual disk stacks on another driver. Physical disks are the main case.
public struct IOKitDiskCounterSource: DiskCounterSource {
    public init() {}

    public func readCounters() -> DiskCounters? {
        var drivers: [[String: Any]] = []
        forEachService(matching: "IOBlockStorageDriver") { service in
            if let stats = dictionaryProperty(service, "Statistics") {
                drivers.append(stats)
            }
        }
        return DiskStatisticsParser.counters(from: drivers)
    }
}

// MARK: - Battery

/// Internal battery state. Power source data comes from IOPS. Health and cycle count come from AppleSmartBattery.
public struct IOKitBatterySource: BatterySource {
    public init() {}

    public func read() -> BatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        var registry: [String: Any] = [:]
        forEachService(matching: "AppleSmartBattery") { service in
            if registry.isEmpty {
                registry = Self.batteryRegistry(service)
            }
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            if var reading = BatteryParser.parse(source: description, registry: registry) {
                reading.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                reading.powerWatts = BatteryParser.powerWatts(registry: registry)
                return reading
            }
        }
        return nil
    }

    private static func batteryRegistry(_ service: io_service_t) -> [String: Any] {
        var values: [String: Any] = [:]
        for key in ["CycleCount", "DesignCapacity", "AppleRawMaxCapacity", "NominalChargeCapacity",
                    "Voltage", "Amperage", "InstantAmperage"] {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() {
                values[key] = value
            }
        }
        return values
    }
}
