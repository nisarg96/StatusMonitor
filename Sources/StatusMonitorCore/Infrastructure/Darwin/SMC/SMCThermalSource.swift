import Dispatch
import Foundation

/// Thermal and fan readings from the SMC.
///
/// Threading:
/// - `probe()` runs once, off the main thread. It opens the connection and finds the sensors.
/// - `latest()` is a non-blocking read of the cached value, safe from the main thread.
/// - `requestRefresh()` queues one background read. At most one is in flight, so a slow SMC never builds up a backlog.
///
/// The connection is opened once and kept for the life of the app, not reopened on every tick.
public final class SMCThermalSource: ThermalSource {
    private struct Sensor {
        let key: String
    }

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "StatusMonitor.SMC", qos: .utility)

    // Guarded by `lock`.
    private var connection: AppleSMCConnection?
    private var temperatureSensors: [Sensor] = []
    private var fanCount = 0
    private var cached: ThermalReading?
    private var refreshInFlight = false

    public init() {}

    public func probe() -> Bool {
        guard let connection = AppleSMCConnection() else { return false }

        let sensors = Self.discoverTemperatureSensors(connection)
        let fans = Self.fanCount(connection)
        guard let reading = Self.read(connection, sensors: sensors, fanCount: fans) else {
            // Nothing decodable: treat the thermal collector as unavailable.
            return false
        }

        lock.lock()
        self.connection = connection
        temperatureSensors = sensors
        fanCount = fans
        cached = reading
        lock.unlock()
        return true
    }

    public func latest() -> ThermalReading? {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    public func requestRefresh() {
        lock.lock()
        guard let connection, !refreshInFlight else {
            lock.unlock()
            return
        }
        refreshInFlight = true
        let sensors = temperatureSensors
        let fans = fanCount
        lock.unlock()

        queue.async { [self] in
            let reading = Self.read(connection, sensors: sensors, fanCount: fans)
            lock.lock()
            // A failed read clears the value, so the section hides instead of showing stale numbers.
            cached = reading
            refreshInFlight = false
            lock.unlock()
        }
    }

    // MARK: - Discovery and reads (run off the main thread)

    private static func discoverTemperatureSensors(_ connection: AppleSMCConnection) -> [Sensor] {
        guard let count = connection.keyCount(), count > 0 else { return [] }
        var sensors: [Sensor] = []
        for index in 0..<count {
            guard let key = connection.key(atIndex: index),
                  TemperatureSelector.isCPUSensorKey(key),
                  let info = connection.keyInfo(key),
                  info.type == "flt " || info.type == "sp78" else { continue }
            sensors.append(Sensor(key: key))
        }
        return sensors
    }

    private static func fanCount(_ connection: AppleSMCConnection) -> Int {
        // FNum is absent on fanless Macs (for example, MacBook Air). That reads as zero fans, and no fan rows are shown.
        guard let entry = connection.read("FNum"),
              let value = SMCDecoder.decode(type: entry.type, bytes: entry.bytes) else { return 0 }
        return Int(value)
    }

    /// Returns nil when neither a temperature nor a fan could be read. A fan that fails alone is skipped, not shown as 0.
    private static func read(
        _ connection: AppleSMCConnection,
        sensors: [Sensor],
        fanCount: Int
    ) -> ThermalReading? {
        let temperatures: [Double] = sensors.compactMap { sensor in
            guard let entry = connection.read(sensor.key) else { return nil }
            return SMCDecoder.decode(type: entry.type, bytes: entry.bytes)
        }
        let cpuTemperature = TemperatureSelector.hottestPlausible(temperatures)

        var fans: [FanSpeed] = []
        for index in 0..<max(0, fanCount) {
            guard let entry = connection.read("F\(index)Ac"),
                  let rpm = SMCDecoder.decode(type: entry.type, bytes: entry.bytes),
                  rpm >= 0 else { continue }
            fans.append(FanSpeed(index: index, rpm: Int(rpm.rounded())))
        }

        guard cpuTemperature != nil || !fans.isEmpty else { return nil }
        return ThermalReading(cpuTemperatureC: cpuTemperature, fans: fans)
    }
}
