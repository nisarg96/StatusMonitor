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
    /// An SMC key with its type and size, read once at probe time. Each tick then reads only the value.
    struct Sensor {
        let key: String
        let info: AppleSMCConnection.KeyInfo
    }

    /// Largest plausible fan count. An FNum above this is a bad read, so no fans are shown.
    static let maxFanCount = 16
    /// Largest plausible fan speed in rpm. Anything above it is a bad read and that fan is skipped.
    static let maxFanRPM = 100_000

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "StatusMonitor.SMC", qos: .utility)

    // Guarded by `lock`.
    private var connection: AppleSMCConnection?
    private var temperatureSensors: [Sensor] = []
    private var fanSensors: [(index: Int, sensor: Sensor)] = []
    private var cached: ThermalReading?
    private var refreshInFlight = false

    public init() {}

    public func probe() -> Bool {
        guard let connection = AppleSMCConnection() else { return false }

        let sensors = Self.discoverTemperatureSensors(connection)
        let fans = Self.discoverFanSensors(connection)
        guard let reading = Self.read(connection, temperatures: sensors, fans: fans) else {
            // Nothing decodable: treat the thermal collector as unavailable.
            return false
        }

        lock.lock()
        self.connection = connection
        temperatureSensors = sensors
        fanSensors = fans
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
        let fans = fanSensors
        lock.unlock()

        queue.async { [self] in
            let reading = Self.read(connection, temperatures: sensors, fans: fans)
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
            sensors.append(Sensor(key: key, info: info))
        }
        return sensors
    }

    /// Looks up each fan's key info once. A fan whose key is missing at probe time is left out.
    private static func discoverFanSensors(_ connection: AppleSMCConnection) -> [(index: Int, sensor: Sensor)] {
        let count = fanCount(connection)
        return (0..<count).compactMap { index in
            let key = "F\(index)Ac"
            guard let info = connection.keyInfo(key) else { return nil }
            return (index, Sensor(key: key, info: info))
        }
    }

    private static func fanCount(_ connection: AppleSMCConnection) -> Int {
        // FNum is absent on fanless Macs (for example, MacBook Air). That reads as zero fans, and no fan rows are
        // shown.
        guard let entry = connection.read("FNum"),
              let value = SMCDecoder.decode(type: entry.type, bytes: entry.bytes) else { return 0 }
        return AppleSMCConnection.integerCount(value, max: maxFanCount) ?? 0
    }

    /// Returns nil when neither a temperature nor a fan could be read. A fan that fails alone is skipped, not shown
    /// as 0. Reads use the key info cached at probe time, so no per-tick key lookup happens.
    static func read(
        _ connection: AppleSMCConnection.KeyReading,
        temperatures: [Sensor],
        fans: [(index: Int, sensor: Sensor)]
    ) -> ThermalReading? {
        let temperatureValues: [Double] = temperatures.compactMap { sensor in
            guard let entry = connection.read(sensor.key, info: sensor.info) else { return nil }
            return SMCDecoder.decode(type: entry.type, bytes: entry.bytes)
        }
        let cpuTemperature = TemperatureSelector.hottestPlausible(temperatureValues)

        var speeds: [FanSpeed] = []
        for (index, sensor) in fans {
            guard let entry = connection.read(sensor.key, info: sensor.info),
                  let rpm = SMCDecoder.decode(type: entry.type, bytes: entry.bytes),
                  let count = AppleSMCConnection.integerCount(rpm, max: maxFanRPM) else { continue }
            speeds.append(FanSpeed(index: index, rpm: count))
        }

        guard cpuTemperature != nil || !speeds.isEmpty else { return nil }
        return ThermalReading(cpuTemperatureC: cpuTemperature, fans: speeds)
    }
}
