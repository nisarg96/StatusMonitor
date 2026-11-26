import Foundation

/// Number formatting shared by the status bar and the popover.
public enum Format {
    /**
     Formats a percentage, such as "12%".

     Clamped to 0...100 and rounded to a whole percent.

     - Parameters:
       - value: The percentage, in percent.
     */
    public static func percent(_ value: Double) -> String {
        "\(Int(min(100, max(0, value)).rounded()))%"
    }

    /**
     Formats a byte count as memory in GB, such as "3.2 GB".

     GB here is GiB (1024³ bytes), matching how macOS reports memory.

     - Parameters:
       - bytes: The byte count.
     */
    public static func gib(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    /**
     Formats a byte rate for display, such as "1.2 MB/s".

     Uses 1024 steps, consistent with `gib`. Values under 1 KB/s show as bytes.

     - Parameters:
       - bytesPerSecond: The rate, in bytes per second. Negative values show as zero.
     - Returns: A string such as "1.2 MB/s" or "340 KB/s".
     */
    public static func rate(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = max(0, bytesPerSecond)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let number = index == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(number) \(units[index])"
    }

    /**
     Formats a duration in minutes, such as "2h 14m", or "45m" under an hour.

     - Parameters:
       - minutes: The duration, in whole minutes.
     */
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }

    /**
     Formats a signed power value in watts.

     Shows "+12.4 W" while charging and "−1.9 W" while discharging.

     - Parameters:
       - value: The power, in watts. Positive while charging, negative while discharging.
     */
    public static func watts(_ value: Double) -> String {
        String(format: "%+.1f W", value).replacingOccurrences(of: "-", with: "−")
    }

    /**
     Formats a temperature in degrees Celsius, such as "54 °C".

     - Parameters:
       - value: The temperature, in degrees Celsius.
     */
    public static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded())) °C"
    }
}

/**
 SF Symbol names for each metric.

 The UI draws these, and the status bar and popover share them, so an icon always means the same metric in both
 places.
 */
public enum MetricSymbol {
    /// CPU load.
    public static let cpu = "cpu"
    /// Used memory (RAM).
    public static let memory = "memorychip"
    /// The memory pressure gauge at its middle needle position. Per-level symbols come from `MemoryPressureNeedle`.
    public static let memoryPressure = "gauge.with.dots.needle.50percent"
    /// GPU utilization.
    public static let gpu = "display"
    /// Network throughput.
    public static let network = "network"
    /// Download direction.
    public static let download = "arrow.down.circle"
    /// Upload direction.
    public static let upload = "arrow.up.circle"
    /// Disk I/O.
    public static let disk = "internaldrive"
    /// Temperature.
    public static let thermal = "thermometer.medium"
    /// Fan speed.
    public static let fan = "fan"

    /**
     Returns the battery icon for a charge level.

     Charging uses the bolt variant.

     - Parameters:
       - percent: The charge level, in percent.
       - charging: Whether the battery is charging.
     - Returns: The SF Symbol name, such as "battery.75" or "battery.100.bolt".
     */
    public static func battery(percent: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        let level: Int
        switch percent {
        case ..<13: level = 0
        case 13..<38: level = 25
        case 38..<63: level = 50
        case 63..<88: level = 75
        default: level = 100
        }
        return "battery.\(level)"
    }
}

/**
 One item in the menu bar: an icon, then a value.

 `plainLabel` is only used for the plain-text title.
 */
public struct TitleSegment: Equatable, Sendable {
    /// The SF Symbol name drawn before the value.
    public let symbol: String
    /// The label used in the plain-text title. Empty when the item has none.
    public let plainLabel: String
    /// The formatted value, such as "8%".
    public let value: String

    /**
     Creates a segment from its symbol, plain label and value.

     - Parameters:
       - symbol: The SF Symbol name drawn before the value.
       - plainLabel: The label used in the plain-text title. Empty when the item has none.
       - value: The formatted value.
     */
    public init(symbol: String, plainLabel: String, value: String) {
        self.symbol = symbol
        self.plainLabel = plainLabel
        self.value = value
    }

    /// Plain text, e.g. "CPU 8%". Used by the CLI and in tests. The menu bar draws the symbol instead.
    public var plainText: String {
        plainLabel.isEmpty ? value : "\(plainLabel) \(value)"
    }
}

/**
 Builds the menu bar segments and the plain-text title from the values that are present.

 A missing value drops its segment, so there are no empty separators, no "N/A", and no zeros.
 */
public enum StatusTitleFormatter {
    /**
     Returns the menu bar segments for a snapshot, in display order.

     Returns no segments before the first sample.

     - Parameters:
       - snapshot: The latest system snapshot.
       - settings: The user's settings, which decide which items are shown.
     */
    public static func segments(for snapshot: SystemSnapshot, settings: MetricSettings) -> [TitleSegment] {
        guard snapshot.isSampled else { return [] }
        var segments: [TitleSegment] = []

        if settings.showCPU {
            segments.append(contentsOf: cpuSegments(snapshot, settings: settings))
        }
        if let gpu = snapshot.gpu, settings.isMenuBarItemShown(.gpu) {
            segments.append(TitleSegment(
                symbol: MetricSymbol.gpu, plainLabel: "GPU",
                value: Format.percent(gpu.utilizationPercent)))
        }
        if let level = snapshot.memoryPressure, settings.isMenuBarItemShown(.memoryPressure) {
            segments.append(TitleSegment(symbol: MetricSymbol.memoryPressure, plainLabel: "Mem", value: level.label))
        }
        if settings.showNetwork {
            segments.append(TitleSegment(
                symbol: MetricSymbol.network, plainLabel: "",
                value: "↓ \(Format.rate(snapshot.downBps)) ↑ \(Format.rate(snapshot.upBps))"
            ))
        }
        if let disk = snapshot.disk, settings.isMenuBarItemShown(.disk) {
            segments.append(TitleSegment(
                symbol: MetricSymbol.disk, plainLabel: "Disk",
                value: "↓ \(Format.rate(disk.readBps)) ↑ \(Format.rate(disk.writeBps))"
            ))
        }
        if settings.isMenuBarItemShown(.battery), settings.isBatteryDetailShown(.menuBarCharge),
           let battery = snapshot.battery, let percent = battery.currentPercent {
            segments.append(TitleSegment(
                symbol: MetricSymbol.battery(percent: percent, charging: battery.isCharging),
                plainLabel: battery.isCharging ? "⚡" : "🔋",
                value: "\(percent)%"
            ))
        }
        if let temperature = snapshot.thermal?.cpuTemperatureC, settings.isMenuBarItemShown(.thermal) {
            segments.append(TitleSegment(
                symbol: MetricSymbol.thermal, plainLabel: "",
                value: Format.celsius(temperature)))
        }

        return segments
    }

    /// Returns the CPU slot's segments. In `.memoryGB` mode the slot shows RAM, so no separate RAM item is added.
    private static func cpuSegments(_ snapshot: SystemSnapshot, settings: MetricSettings) -> [TitleSegment] {
        var segments: [TitleSegment] = []
        switch settings.cpuMode {
        case .percent:
            segments.append(TitleSegment(
                symbol: MetricSymbol.cpu, plainLabel: "CPU",
                value: Format.percent(snapshot.cpuPercent)))
        case .memoryGB:
            if settings.isMenuBarItemShown(.ram) {
                segments.append(TitleSegment(
                    symbol: MetricSymbol.memory, plainLabel: "RAM",
                    value: Format.gib(snapshot.memoryUsedBytes)))
            }
        }
        if settings.cpuMode == .percent, settings.isMenuBarItemShown(.ram) {
            segments.append(TitleSegment(
                symbol: MetricSymbol.memory, plainLabel: "RAM",
                value: Format.gib(snapshot.memoryUsedBytes)))
        }
        return segments
    }

    /**
     Returns the plain-text menu bar title.

     Returns "SM" when nothing is shown, so the status item stays clickable.

     - Parameters:
       - snapshot: The latest system snapshot.
       - settings: The user's settings, which decide which items are shown.
     - Returns: A title such as "CPU 8% · GPU 12% · 🔋 84%".
     */
    public static func title(for snapshot: SystemSnapshot, settings: MetricSettings) -> String {
        let segments = segments(for: snapshot, settings: settings)
        return segments.isEmpty ? "SM" : segments.map(\.plainText).joined(separator: " · ")
    }
}

/// Builds the value segment for one status bar item.
public enum MenuBarItemFormatter {
    /**
     Returns the value segment for one status bar item.

     Returns nil when the item has no value yet, including before the first sample, so the icon shows alone.

     - Parameters:
       - item: The status bar item.
       - snapshot: The latest system snapshot.
       - settings: The user's settings. Not read by this function.
     - Returns: The item's segment, or nil when it has no value.
     */
    public static func segment(
        for item: MetricItemID,
        snapshot: SystemSnapshot,
        settings: MetricSettings
    ) -> TitleSegment? {
        guard snapshot.isSampled else { return nil }
        return sampledSegment(for: item, snapshot: snapshot)
    }

    private static func sampledSegment(for item: MetricItemID, snapshot: SystemSnapshot) -> TitleSegment? {
        switch item {
        case .cpu:
            return TitleSegment(symbol: MetricSymbol.cpu, plainLabel: "CPU", value: Format.percent(snapshot.cpuPercent))
        case .ram:
            return TitleSegment(
                symbol: MetricSymbol.memory, plainLabel: "RAM",
                value: Format.gib(snapshot.memoryUsedBytes))
        case .gpu:
            return snapshot.gpu.map { gpu in
                TitleSegment(
                    symbol: MetricSymbol.gpu, plainLabel: "GPU",
                    value: Format.percent(gpu.utilizationPercent))
            }
        case .memoryPressure:
            guard let level = snapshot.memoryPressure else { return nil }
            return TitleSegment(symbol: MetricSymbol.memoryPressure, plainLabel: "Mem", value: level.label)
        case .network:
            return TitleSegment(
                symbol: MetricSymbol.network, plainLabel: "",
                value: "↓ \(Format.rate(snapshot.downBps)) ↑ \(Format.rate(snapshot.upBps))"
            )
        case .disk:
            guard let disk = snapshot.disk else { return nil }
            return TitleSegment(
                symbol: MetricSymbol.disk, plainLabel: "Disk",
                value: "↓ \(Format.rate(disk.readBps)) ↑ \(Format.rate(disk.writeBps))"
            )
        case .battery:
            return batterySegment(snapshot)
        case .thermal:
            return snapshot.thermal?.cpuTemperatureC.map {
                TitleSegment(symbol: MetricSymbol.thermal, plainLabel: "", value: Format.celsius($0))
            }
        }
    }

    private static func batterySegment(_ snapshot: SystemSnapshot) -> TitleSegment? {
        guard let battery = snapshot.battery, let percent = battery.currentPercent else { return nil }
        return TitleSegment(
            symbol: MetricSymbol.battery(percent: percent, charging: battery.isCharging),
            plainLabel: battery.isCharging ? "⚡" : "🔋",
            value: "\(percent)%"
        )
    }
}

/// One line in the popover's live readout.
public struct ReadoutRow: Equatable, Identifiable, Sendable {
    /// A stable identifier for the row, such as "cpu" or "diskRead".
    public let id: String
    /// The optional collector this row belongs to. Nil for the always-on CPU, RAM, and network rows.
    public let collector: CollectorKind?
    /// SF Symbol shown before the label.
    public let symbol: String
    /// The row's label, such as "CPU temp".
    public let label: String
    /// The formatted value, such as "12%".
    public let value: String
    /// The colour state of the value, or nil for the default colour.
    public let accent: ReadoutAccent?

    /**
     Creates a readout row.

     - Parameters:
       - id: A stable identifier for the row.
       - collector: The optional collector the row belongs to. Nil for the always-on rows.
       - symbol: The SF Symbol shown before the label.
       - label: The row's label.
       - value: The formatted value.
       - accent: The colour state of the value, or nil for the default colour.
     */
    public init(
        id: String,
        collector: CollectorKind? = nil,
        symbol: String,
        label: String,
        value: String,
        accent: ReadoutAccent? = nil
    ) {
        self.id = id
        self.collector = collector
        self.symbol = symbol
        self.label = label
        self.value = value
        self.accent = accent
    }
}

/// Parses the free-text interface field ("en0, utun3") into a set of names.
public enum InterfaceAllowListParser {
    /**
     Splits the interface field into names.

     Names are separated by commas. Spaces are trimmed and empty entries are dropped.

     - Parameters:
       - text: The raw text of the field.
     */
    public static func parse(_ text: String) -> Set<String> {
        Set(
            text.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}
