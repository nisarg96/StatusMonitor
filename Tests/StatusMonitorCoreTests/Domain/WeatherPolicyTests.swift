import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("WeatherRefreshInterval")
struct WeatherRefreshIntervalTests {
    @Test("defaults to 15 minutes")
    func defaultValue() {
        #expect(WeatherRefreshInterval.defaultMinutes == 15)
    }

    @Test("clamps to the 10–60 minute range")
    func clamps() {
        #expect(WeatherRefreshInterval.clamped(minutes: 1) == 10)
        #expect(WeatherRefreshInterval.clamped(minutes: 15) == 15)
        #expect(WeatherRefreshInterval.clamped(minutes: 500) == 60)
        #expect(WeatherRefreshInterval.seconds(minutes: 5) == 600)
    }
}

@Suite("WeatherCachePolicy")
struct WeatherCachePolicyTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("next fetch waits for the refresh interval when no expiry is set")
    func nextFetchByInterval() {
        let next = WeatherCachePolicy.nextFetch(lastFetch: t0, intervalSeconds: 900, expiresAt: nil)
        #expect(next == t0.addingTimeInterval(900))
    }

    @Test("next fetch never comes before the data's expiry")
    func nextFetchHonoursExpiry() {
        let expiry = t0.addingTimeInterval(1_800)
        let next = WeatherCachePolicy.nextFetch(lastFetch: t0, intervalSeconds: 900, expiresAt: expiry)
        #expect(next == expiry)
    }

    @Test("cached data is only reused for the same location key")
    func locationKeyMatch() {
        let snapshot = WeatherSnapshot(timestamp: t0, provider: .openMeteo)
        #expect(WeatherCachePolicy.isUsable(snapshot, forKey: "28.61,77.21", cachedKey: "28.61,77.21"))
        #expect(!WeatherCachePolicy.isUsable(snapshot, forKey: "19.07,72.87", cachedKey: "28.61,77.21"))
    }

    @Test("location keys round to 0.01 degrees, so nearby points share a cache entry")
    func cacheKeyRounding() {
        #expect(WeatherLocation(latitude: 28.6139, longitude: 77.2090).cacheKey == "28.61,77.21")
        #expect(WeatherLocation(latitude: 28.6141, longitude: 77.2088).cacheKey == "28.61,77.21")
    }

    @Test("freshness: fresh before expiry, stale within the grace period, expired after it")
    func freshness() {
        let expiry = t0.addingTimeInterval(600)
        let snapshot = WeatherSnapshot(timestamp: t0, provider: .openMeteo, expiresAt: expiry)
        #expect(WeatherCachePolicy.freshness(of: snapshot, now: t0.addingTimeInterval(599)) == .fresh)
        #expect(WeatherCachePolicy.freshness(of: snapshot, now: expiry.addingTimeInterval(60)) == .stale)
        let pastGrace = expiry.addingTimeInterval(WeatherCachePolicy.ruleGraceSeconds + 1)
        #expect(WeatherCachePolicy.freshness(of: snapshot, now: pastGrace) == .expired)
    }

    @Test("the rule grace period is 30 minutes, as agreed")
    func graceIsThirtyMinutes() {
        #expect(WeatherCachePolicy.ruleGraceSeconds == 1_800)
    }
}

@Suite("WMOCodeMapper")
struct WMOCodeMapperTests {
    @Test("clear sky uses the sun by day and the moon at night")
    func clearDayNight() {
        #expect(WMOCodeMapper.condition(for: 0, isDay: true)?.symbolName == "sun.max.fill")
        #expect(WMOCodeMapper.condition(for: 0, isDay: false)?.symbolName == "moon.stars.fill")
    }

    @Test("rain codes map to a rain label")
    func rain() {
        #expect(WMOCodeMapper.condition(for: 63, isDay: true)?.label == "Rain")
    }

    @Test("an unknown code maps to nil, never to a wrong icon")
    func unknownIsNil() {
        #expect(WMOCodeMapper.condition(for: 1234, isDay: true) == nil)
    }
}

@Suite("OpenMeteoParser")
struct OpenMeteoParserTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test("parses a full current block into canonical units")
    func fullBlock() throws {
        let json = """
        {"interval": 900, "current": {"temperature_2m": 21.4, "apparent_temperature": 20.1,
        "relative_humidity_2m": 63, "precipitation": 0.2, "precipitation_probability": 40,
        "wind_speed_10m": 12.5, "wind_direction_10m": 230, "weather_code": 61, "is_day": 1, "uv_index": 3.2}}
        """
        let snapshot = try OpenMeteoParser.parse(data(json), now: now)
        #expect(snapshot.temperatureC == 21.4)
        #expect(snapshot.feelsLikeC == 20.1)
        #expect(snapshot.humidityPercent == 63)
        #expect(snapshot.precipitationProbabilityPercent == 40)
        #expect(snapshot.windSpeedKMH == 12.5)
        #expect(snapshot.uvIndex == 3.2)
        #expect(snapshot.conditionLabel == "Rain")
        #expect(snapshot.symbolName == "cloud.rain.fill")
        #expect(snapshot.provider == .openMeteo)
        #expect(snapshot.expiresAt == now.addingTimeInterval(900))
    }

    @Test("a missing field is nil, never zero")
    func missingFieldsAreNil() throws {
        let json = #"{"current": {"temperature_2m": 18}}"#
        let snapshot = try OpenMeteoParser.parse(data(json), now: now)
        #expect(snapshot.temperatureC == 18)
        #expect(snapshot.uvIndex == nil)
        #expect(snapshot.precipitationProbabilityPercent == nil)
        #expect(snapshot.conditionLabel == nil)
        #expect(snapshot.expiresAt == nil)
    }

    @Test("a JSON boolean is not read as a number")
    func booleanIgnored() throws {
        let json = #"{"current": {"temperature_2m": true}}"#
        let snapshot = try OpenMeteoParser.parse(data(json), now: now)
        #expect(snapshot.temperatureC == nil)
    }

    @Test("no current block is an error, not an empty reading")
    func noCurrentBlock() {
        #expect(throws: OpenMeteoParser.ParseError.missingCurrentBlock) {
            try OpenMeteoParser.parse(data(#"{"daily": {}}"#), now: now)
        }
    }

    @Test("non-JSON input is an error")
    func notJSON() {
        #expect(throws: OpenMeteoParser.ParseError.notJSON) {
            try OpenMeteoParser.parse(data("<html>"), now: now)
        }
    }

    @Test("the request asks for the variables the app uses, in km/h")
    func requestURL() throws {
        let url = try #require(OpenMeteoRequest.forecastURL(for: WeatherLocation(latitude: 28.61, longitude: 77.21)))
        let query = url.absoluteString
        #expect(query.hasPrefix("https://api.open-meteo.com/v1/forecast"))
        #expect(query.contains("precipitation_probability"))
        #expect(query.contains("wind_speed_unit=kmh"))
    }
}
