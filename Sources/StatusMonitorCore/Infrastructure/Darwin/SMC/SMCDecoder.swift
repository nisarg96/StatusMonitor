import Foundation

/**
 Decodes raw SMC value bytes according to their declared four-character type.

 Unknown types decode to nil, so the value is skipped instead of shown wrong.
 */
enum SMCDecoder {
    /**
     Decodes an SMC value by its four-character type code.

     - Parameters:
       - type: The declared type, for example `flt `, `sp78`, `fpe2`, `ui8 `, `ui16` or `ui32`.
       - bytes: The raw value bytes.
     - Returns: The decoded number, or nil for an unknown type or too few bytes.
     */
    static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ": return decodeFloat(bytes)
        case "sp78": return decodeSP78(bytes)
        case "fpe2": return decodeFPE2(bytes)
        case "ui8 ": return decodeUI8(bytes)
        case "ui16": return decodeUI16(bytes)
        case "ui32": return decodeUI32(bytes)
        default: return nil
        }
    }

    /// Little-endian IEEE-754 float (Apple Silicon and recent Intel SMC).
    private static func decodeFloat(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let value = Double(Float(bitPattern: bits))
        return value.isFinite ? value : nil
    }

    /// Signed 8.8 fixed point, big-endian (classic Intel temperatures).
    private static func decodeSP78(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        return Double(raw) / 256
    }

    /// Unsigned 14.2 fixed point, big-endian (classic Intel fan RPM).
    private static func decodeFPE2(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        return Double(raw) / 4
    }

    /// Unsigned 8-bit integer.
    private static func decodeUI8(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 1 else { return nil }
        return Double(bytes[0])
    }

    /// Unsigned 16-bit integer, big-endian.
    private static func decodeUI16(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
    }

    /// Unsigned 32-bit integer, big-endian.
    private static func decodeUI32(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let raw = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        return Double(raw)
    }
}

/**
 Chooses the CPU temperature from the candidate sensors.

 Sensor key names differ between Intel and Apple Silicon generations, so this does not hardcode one key.
 It takes the hottest plausible reading from the CPU-prefixed sensors.
 */
enum TemperatureSelector {
    /**
     Returns the hottest plausible CPU temperature.

     Values outside 5...125 °C are rejected as bad reads.

     - Parameters:
       - values: Candidate temperatures in degrees Celsius.
     - Returns: The highest accepted value, or nil when none qualify.
     */
    static func hottestPlausible(_ values: [Double]) -> Double? {
        values.filter { $0 > 5 && $0 < 125 }.max()
    }

    /**
     Reports whether an SMC key name belongs to a CPU sensor.

     Only keys with the `TC`, `Tp` or `Te` prefix are considered CPU sensors.

     - Parameters:
       - key: The SMC key name.
     - Returns: True when the key has a CPU sensor prefix.
     */
    static func isCPUSensorKey(_ key: String) -> Bool {
        key.hasPrefix("TC") || key.hasPrefix("Tp") || key.hasPrefix("Te")
    }
}
