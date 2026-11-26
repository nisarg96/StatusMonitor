import Foundation

/// Maps WMO weather interpretation codes (as returned by Open-Meteo) to a label and an SF Symbol.
/// Unknown codes map to nil, so the UI shows no icon instead of a wrong one.
public enum WMOCodeMapper {
    public struct Condition: Equatable, Sendable {
        public let label: String
        public let symbolName: String
    }

    public static func condition(for code: Int, isDay: Bool) -> Condition? {
        switch code {
        case 0:
            return Condition(label: "Clear", symbolName: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2:
            return Condition(label: "Partly cloudy", symbolName: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return Condition(label: "Overcast", symbolName: "cloud.fill")
        case 45, 48:
            return Condition(label: "Fog", symbolName: "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return Condition(label: "Drizzle", symbolName: "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67:
            return Condition(label: "Rain", symbolName: "cloud.rain.fill")
        case 71, 73, 75, 77:
            return Condition(label: "Snow", symbolName: "cloud.snow.fill")
        case 80, 81, 82:
            return Condition(label: "Showers", symbolName: "cloud.heavyrain.fill")
        case 85, 86:
            return Condition(label: "Snow showers", symbolName: "cloud.snow.fill")
        case 95, 96, 99:
            return Condition(label: "Thunderstorm", symbolName: "cloud.bolt.rain.fill")
        default:
            return nil
        }
    }
}
