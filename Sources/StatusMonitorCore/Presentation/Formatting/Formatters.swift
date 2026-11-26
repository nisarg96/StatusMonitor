import Foundation

/// Number formatting shared by the status bar and the popover.
public enum Format {
    /// "12%". Clamped to 0...100 and rounded to a whole percent.
    public static func percent(_ value: Double) -> String {
        "\(Int(min(100, max(0, value)).rounded()))%"
    }

    /// "3.2 GB". GB here is GiB (1024³ bytes), matching how macOS reports memory.
    public static func gib(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    /// "1.2 MB/s". Uses 1024 steps, consistent with `gib`. Values under 1 KB/s show as bytes.
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

    /// "2h 14m", or "45m" under an hour.
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }

    /// Signed power: "+12.4 W" while charging, "−1.9 W" while discharging.
    public static func watts(_ value: Double) -> String {
        String(format: "%+.1f W", value).replacingOccurrences(of: "-", with: "−")
    }

    /// "54 °C"
    public static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded())) °C"
    }
}

/// SF Symbol names for each metric. The UI draws these, and the status bar and popover share them,
/// so an icon always means the same metric in both places.
public enum MetricSymbol {
    public static let cpu = "cpu"
    public static let memory = "memorychip"
    public static let memoryPressure = "gauge.with.dots.needle.50percent"
    public static let gpu = "display"
    public static let network = "network"
    public static let download = "arrow.down.circle"
    public static let upload = "arrow.up.circle"
    public static let disk = "internaldrive"
    public static let thermal = "thermometer.medium"
    public static let fan = "fan"

    /// Battery icon for a charge level: battery.0 / .25 / .50 / .75 / .100. Charging uses the bolt variant.
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

/// One item in the menu bar: an icon, then a value. `plainLabel` is only used for the plain-text title.
public struct TitleSegment: Equatable, Sendable {
    public let symbol: String
    public let plainLabel: String
    public let value: String

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

/// Builds the menu bar segments from whichever values are present. A missing value drops its segment,
/// so there are no empty separators, no "N/A", and no zeros.
public enum StatusTitleFormatter {
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

    private static func cpuSegments(_ snapshot: SystemSnapshot, settings: MetricSettings) -> [TitleSegment] {
        var segments: [TitleSegment] = []
        switch settings.cpuMode {
        case .percent:
            segments.append(TitleSegment(
                symbol: MetricSymbol.cpu, plainLabel: "CPU",
                value: Format.percent(snapshot.cpuPercent)))
        case .memoryGB:
            // The CPU slot shows RAM in this mode, so a separate RAM item would repeat it.
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

    /// Plain-text title, e.g. "CPU 8% · GPU 12% · 🔋 84%". Returns "SM" when nothing is shown,
    /// so the status item stays clickable.
    public static func title(for snapshot: SystemSnapshot, settings: MetricSettings) -> String {
        let segments = segments(for: snapshot, settings: settings)
        return segments.isEmpty ? "SM" : segments.map(\.plainText).joined(separator: " · ")
    }
}

/// One segment per status bar item. Returns nil when the item has no value yet, so the caller can show the icon alone.
public enum MenuBarItemFormatter {
    public static func segment(
        for item: MetricItemID,
        snapshot: SystemSnapshot,
        settings: MetricSettings
    ) -> TitleSegment? {
        // Before the first sample the value is not real, so the item shows its icon alone.
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
    public let id: String
    /// The optional collector this row belongs to. Nil for the always-on CPU, RAM, and network rows.
    public let collector: CollectorKind?
    /// SF Symbol shown before the label.
    public let symbol: String
    public let label: String
    public let value: String
    public let accent: ReadoutAccent?

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
    public static func parse(_ text: String) -> Set<String> {
        Set(
            text.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}
