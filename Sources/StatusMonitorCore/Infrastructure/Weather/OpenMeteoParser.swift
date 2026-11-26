import Foundation

/// Parses the Open-Meteo `/v1/forecast` JSON into a `WeatherSnapshot`. Pure: no network, so it runs against fixtures.
/// Missing or malformed fields become nil. A missing value is never replaced with zero.
public enum OpenMeteoParser {
    public enum ParseError: Error, Equatable {
        case notJSON
        case missingCurrentBlock
    }

    public static func parse(_ data: Data, now: Date) throws -> WeatherSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.notJSON
        }
        guard let current = root["current"] as? [String: Any] else {
            throw ParseError.missingCurrentBlock
        }

        let code = number(current["weather_code"]).map { Int($0) }
        let isDay = (number(current["is_day"]) ?? 1) != 0
        let condition = code.flatMap { WMOCodeMapper.condition(for: $0, isDay: isDay) }

        // Open-Meteo reports the time as local ISO text. The `interval` (seconds) tells us when the reading ends.
        let expiresAt: Date? = {
            guard let interval = number(root["interval"]) ?? number(current["interval"]) else { return nil }
            return now.addingTimeInterval(interval)
        }()

        return WeatherSnapshot(
            timestamp: now,
            temperatureC: number(current["temperature_2m"]),
            feelsLikeC: number(current["apparent_temperature"]),
            humidityPercent: number(current["relative_humidity_2m"]),
            precipitationMM: number(current["precipitation"]),
            precipitationProbabilityPercent: number(current["precipitation_probability"]),
            windSpeedKMH: number(current["wind_speed_10m"]),
            windDirectionDegrees: number(current["wind_direction_10m"]),
            uvIndex: number(current["uv_index"]),
            conditionLabel: condition?.label,
            symbolName: condition?.symbolName,
            provider: .openMeteo,
            expiresAt: expiresAt
        )
    }

    /// Reads a JSON number, or nil when the field is absent or not numeric.
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber:
            // NSNumber also wraps booleans; ignore those so they are not read as 0 or 1 measurements.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            return n.doubleValue.isFinite ? n.doubleValue : nil
        default:
            return nil
        }
    }
}

/// Builds the Open-Meteo forecast URL for the variables the app uses.
public enum OpenMeteoRequest {
    public static let currentVariables = [
        "temperature_2m", "apparent_temperature", "relative_humidity_2m", "precipitation",
        "precipitation_probability", "wind_speed_10m", "wind_direction_10m", "weather_code",
        "uv_index", "is_day",
    ]

    public static func forecastURL(for location: WeatherLocation) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.longitude)),
            URLQueryItem(name: "current", value: currentVariables.joined(separator: ",")),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
        ]
        return components?.url
    }
}
