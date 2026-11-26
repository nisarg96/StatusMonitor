import Foundation

/// The gauge symbol for each memory pressure level. The needle sits low, mid or high, so the state reads without
/// colour.
public enum MemoryPressureNeedle {
    public static func symbol(for level: MemoryPressureLevel) -> String {
        switch level {
        case .normal: return "gauge.with.dots.needle.0percent"
        case .warning: return "gauge.with.dots.needle.50percent"
        case .critical: return "gauge.with.dots.needle.100percent"
        }
    }
}
