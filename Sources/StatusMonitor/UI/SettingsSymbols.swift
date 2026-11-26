import StatusMonitorCore

/// The SF Symbol for each menu bar item, used where an item needs a picture of itself, such as the preview fallback.
enum SettingsSymbols {
    /**
     Returns the SF Symbol name for a menu bar item.

     - Parameter item: The menu bar item.
     - Returns: The symbol name.
     */
    static func symbol(for item: MetricItemID) -> String {
        switch item {
        case .cpu: return MetricSymbol.cpu
        case .ram: return MetricSymbol.memory
        case .gpu: return MetricSymbol.gpu
        case .memoryPressure: return MetricSymbol.memoryPressure
        case .network: return MetricSymbol.network
        case .disk: return MetricSymbol.disk
        case .battery: return MetricSymbol.battery(percent: 100, charging: false)
        case .thermal: return MetricSymbol.thermal
        }
    }
}
