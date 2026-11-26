import Foundation

/// Provider-agnostic weather reading. Units are canonical: °C, km/h, %, mm, degrees. Presentation converts for display.
public struct WeatherSnapshot: Equatable, Codable, Sendable {
    public var timestamp: Date
    public var temperatureC: Double?
    public var feelsLikeC: Double?
    public var humidityPercent: Double?
    public var precipitationMM: Double?
    /// Chance of precipitation for the current hour, 0...100.
    public var precipitationProbabilityPercent: Double?
    public var windSpeedKMH: Double?
    public var windDirectionDegrees: Double?
    public var uvIndex: Double?
    public var conditionLabel: String?
    /// SF Symbol for the current condition.
    public var symbolName: String?
    public var provider: WeatherProviderKind
    /// When this reading should be replaced. Nil means "use the refresh interval".
    public var expiresAt: Date?

    public init(
        timestamp: Date,
        temperatureC: Double? = nil,
        feelsLikeC: Double? = nil,
        humidityPercent: Double? = nil,
        precipitationMM: Double? = nil,
        precipitationProbabilityPercent: Double? = nil,
        windSpeedKMH: Double? = nil,
        windDirectionDegrees: Double? = nil,
        uvIndex: Double? = nil,
        conditionLabel: String? = nil,
        symbolName: String? = nil,
        provider: WeatherProviderKind,
        expiresAt: Date? = nil
    ) {
        self.timestamp = timestamp
        self.temperatureC = temperatureC
        self.feelsLikeC = feelsLikeC
        self.humidityPercent = humidityPercent
        self.precipitationMM = precipitationMM
        self.precipitationProbabilityPercent = precipitationProbabilityPercent
        self.windSpeedKMH = windSpeedKMH
        self.windDirectionDegrees = windDirectionDegrees
        self.uvIndex = uvIndex
        self.conditionLabel = conditionLabel
        self.symbolName = symbolName
        self.provider = provider
        self.expiresAt = expiresAt
    }
}

public enum WeatherProviderKind: String, Codable, Sendable {
    case weatherKit = "WeatherKit"
    case openMeteo = "Open-Meteo"
}

/// Where the weather is for. Coordinates are the source of truth; `name` is only for display.
public struct WeatherLocation: Equatable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var name: String?

    public init(latitude: Double, longitude: Double, name: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }

    /// Coordinates rounded to 0.01°, about 1 km. Locations that round to the same key share a cache entry.
    public var cacheKey: String {
        String(format: "%.2f,%.2f", latitude, longitude)
    }
}

/// Refresh interval, always clamped to 10–60 minutes. Default 15.
public enum WeatherRefreshInterval {
    public static let defaultMinutes = 15
    public static let minimumMinutes = 10
    public static let maximumMinutes = 60

    public static func clamped(minutes: Int) -> Int {
        min(maximumMinutes, max(minimumMinutes, minutes))
    }

    public static func seconds(minutes: Int) -> TimeInterval {
        TimeInterval(clamped(minutes: minutes) * 60)
    }
}

/// How fresh a cached reading is.
public enum WeatherFreshness: Equatable, Sendable {
    case fresh
    /// Past its expiry, but still within the rule grace period.
    case stale
    /// Past the grace period. Rules must go idle, and the UI must not show it as current.
    case expired
}

/// Pure cache rules. No I/O, so every timing decision is testable.
public enum WeatherCachePolicy {
    /// Rules may keep using data this long past its expiry, then they go idle.
    public static let ruleGraceSeconds: TimeInterval = 30 * 60

    /// Next time a fetch is allowed. Never before the cached reading's expiry, and never sooner than the refresh interval.
    public static func nextFetch(lastFetch: Date, intervalSeconds: TimeInterval, expiresAt: Date?) -> Date {
        let byInterval = lastFetch.addingTimeInterval(intervalSeconds)
        guard let expiresAt else { return byInterval }
        return max(byInterval, expiresAt)
    }

    /// The cached reading is only reused for the location it was fetched for.
    public static func isUsable(_ snapshot: WeatherSnapshot, forKey key: String, cachedKey: String) -> Bool {
        key == cachedKey
    }

    public static func freshness(of snapshot: WeatherSnapshot, now: Date) -> WeatherFreshness {
        guard let expiresAt = snapshot.expiresAt else {
            // Without an expiry, the reading ages from its timestamp, using the grace period.
            return now.timeIntervalSince(snapshot.timestamp) <= ruleGraceSeconds ? .fresh : .expired
        }
        if now <= expiresAt { return .fresh }
        return now.timeIntervalSince(expiresAt) <= ruleGraceSeconds ? .stale : .expired
    }
}
