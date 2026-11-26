import Foundation

/**
 Maps memory pressure levels to gauge symbols.

 The needle sits low, mid or high, so the state reads without colour.
 */
public enum MemoryPressureNeedle {
    /**
     Returns the gauge symbol for a memory pressure level.

     - Parameters:
       - level: The memory pressure level.
     - Returns: The SF Symbol name for the level's needle position.
     */
    public static func symbol(for level: MemoryPressureLevel) -> String {
        switch level {
        case .normal: return "gauge.with.dots.needle.0percent"
        case .warning: return "gauge.with.dots.needle.50percent"
        case .critical: return "gauge.with.dots.needle.100percent"
        }
    }
}
