import Foundation

/**
 One direction of network traffic. The Network item and its popover card show each enabled direction and hide the
 rest.
 */
public enum NetworkDirection: String, CaseIterable, Sendable {
    /// Incoming traffic, shown with a down arrow.
    case download
    /// Outgoing traffic, shown with an up arrow.
    case upload

    /**
     Returns the directions the user has switched on, download first.

     This is the one rule for both the menu bar and the popover card. An empty result means no direction is on. The
     Network item is then hidden from the menu bar, and the card has no direction rows.

     - Parameters:
       - showDownload: Whether download is shown.
       - showUpload: Whether upload is shown.
     - Returns: The enabled directions, download first. Empty when both are off.
     */
    public static func shown(showDownload: Bool, showUpload: Bool) -> [NetworkDirection] {
        var directions: [NetworkDirection] = []
        if showDownload { directions.append(.download) }
        if showUpload { directions.append(.upload) }
        return directions
    }

    /**
     Returns the directions enabled in the user's settings.

     - Parameter settings: The user's settings.
     - Returns: The enabled directions, download first. Empty when both are off.
     */
    public static func shown(in settings: MetricSettings) -> [NetworkDirection] {
        shown(showDownload: settings.showDownload, showUpload: settings.showUpload)
    }

    /// The arrow drawn before this direction's rate: ↓ for download, ↑ for upload.
    public var arrow: String {
        switch self {
        case .download: return "↓"
        case .upload: return "↑"
        }
    }

    /// The history series that holds this direction's rate.
    var historySeries: HistorySeries {
        switch self {
        case .download: return .networkDown
        case .upload: return .networkUp
        }
    }

    /**
     Returns this direction's rate from a pair of rates.

     - Parameters:
       - upBps: The upload rate, in bytes per second.
       - downBps: The download rate, in bytes per second.
     - Returns: The rate for this direction, in bytes per second.
     */
    public func rate(upBps: Double, downBps: Double) -> Double {
        switch self {
        case .download: return downBps
        case .upload: return upBps
        }
    }
}
