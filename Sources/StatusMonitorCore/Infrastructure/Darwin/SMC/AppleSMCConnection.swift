import IOKit

/// Minimal client for the AppleSMC user client.
///
/// The SMCKeyData_t struct is 80 bytes. Fields are written and read by explicit byte offset,
/// so the code does not depend on Swift's struct layout:
///   0  key (UInt32, four-character code)
///   28 keyInfo.dataSize (UInt32), 32 keyInfo.dataType (UInt32), 36 keyInfo.dataAttributes
///   40 result (UInt8), 42 data8 (command), 44 data32 (index), 48..79 bytes
///
/// Not thread-safe. The owner serializes calls, see SMCThermalSource.
final class AppleSMCConnection {
    /// What the thermal source needs from the SMC. A seam so the cached-key read path can be tested without hardware.
    protocol KeyReading: AnyObject {
        func keyInfo(_ key: String) -> AppleSMCConnection.KeyInfo?
        func read(_ key: String, info: AppleSMCConnection.KeyInfo) -> (type: String, bytes: [UInt8])?
    }

    /// Upper bound on the SMC key count. A real Mac has a few thousand keys, so anything above this is a bad read.
    static let maxKeyCount = 65_536

    private enum Selector {
        static let kernelIndex: UInt32 = 2
        static let readBytes: UInt8 = 5
        static let keyFromIndex: UInt8 = 8
        static let readKeyInfo: UInt8 = 9
    }

    private static let structSize = 80
    private var connection: io_connect_t = 0

    /// Returns nil when AppleSMC is missing or cannot be opened (for example, a sandboxed build).
    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS, connection != 0 else {
            return nil
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    struct KeyInfo {
        let size: Int
        let type: String
    }

    /// Reads a key's declared type and size.
    func keyInfo(_ key: String) -> KeyInfo? {
        guard let code = Self.fourCC(key) else { return nil }
        var input = Self.emptyStruct()
        Self.writeU32(&input, 0, code)
        input[42] = Selector.readKeyInfo
        guard let output = call(input), output[40] == 0 else { return nil }
        let size = Int(Self.readU32(output, 28))
        guard size > 0, size <= 32 else { return nil }
        return KeyInfo(size: size, type: Self.string(fourCC: Self.readU32(output, 32)))
    }

    /// Reads a key's raw bytes, including its declared type. Looks up the key info first.
    func read(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard let info = keyInfo(key) else { return nil }
        return read(key, info: info)
    }

    /// Reads a key's raw bytes using key info obtained earlier, such as at probe time. Skips the key-info lookup.
    func read(_ key: String, info: KeyInfo) -> (type: String, bytes: [UInt8])? {
        guard let code = Self.fourCC(key) else { return nil }
        var input = Self.emptyStruct()
        Self.writeU32(&input, 0, code)
        Self.writeU32(&input, 28, UInt32(info.size))
        input[42] = Selector.readBytes
        guard let output = call(input), output[40] == 0 else { return nil }
        return (info.type, Array(output[48..<(48 + info.size)]))
    }

    /// Number of keys in the SMC, from the "#KEY" key.
    func keyCount() -> Int? {
        guard let entry = read("#KEY"),
              let value = SMCDecoder.decode(type: entry.type, bytes: entry.bytes) else { return nil }
        return Self.integerCount(value, max: Self.maxKeyCount)
    }

    /// Converts a decoded SMC number to a count. Returns nil for NaN, infinity, negatives and anything above `max`,
    /// because `Int(Double)` traps on those.
    static func integerCount(_ value: Double, max: Int) -> Int? {
        guard value.isFinite, value >= 0, value <= Double(max) else { return nil }
        return Int(value.rounded())
    }

    /// Key name at a given index, used to enumerate sensors.
    func key(atIndex index: Int) -> String? {
        var input = Self.emptyStruct()
        input[42] = Selector.keyFromIndex
        Self.writeU32(&input, 44, UInt32(index))
        guard let output = call(input), output[40] == 0 else { return nil }
        return Self.string(fourCC: Self.readU32(output, 0))
    }

    private func call(_ input: [UInt8]) -> [UInt8]? {
        var inputBuffer = input
        var outputBuffer = [UInt8](repeating: 0, count: Self.structSize)
        var outputSize = Self.structSize
        let kernelResult = IOConnectCallStructMethod(
            connection, Selector.kernelIndex,
            &inputBuffer, Self.structSize,
            &outputBuffer, &outputSize
        )
        guard kernelResult == KERN_SUCCESS else { return nil }
        return outputBuffer
    }

    // MARK: - Byte helpers

    private static func emptyStruct() -> [UInt8] {
        [UInt8](repeating: 0, count: structSize)
    }

    /// Four-character codes are big-endian, for example "TC0P" -> 0x54433050. Returns nil unless the string is
    /// exactly 4 ASCII bytes.
    static func fourCC(_ key: String) -> UInt32? {
        let bytes = Array(key.utf8)
        guard bytes.count == 4 else { return nil }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    static func string(fourCC value: UInt32) -> String {
        let bytes = [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// Native (little-endian on every supported Mac) store, matching the layout the SMC driver expects.
    private static func writeU32(_ buffer: inout [UInt8], _ offset: Int, _ value: UInt32) {
        buffer[offset] = UInt8(value & 0xFF)
        buffer[offset + 1] = UInt8((value >> 8) & 0xFF)
        buffer[offset + 2] = UInt8((value >> 16) & 0xFF)
        buffer[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    private static func readU32(_ buffer: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
            | UInt32(buffer[offset + 2]) << 16 | UInt32(buffer[offset + 3]) << 24
    }
}

extension AppleSMCConnection: AppleSMCConnection.KeyReading {}
