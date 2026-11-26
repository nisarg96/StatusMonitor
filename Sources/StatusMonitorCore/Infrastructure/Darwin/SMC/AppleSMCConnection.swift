import IOKit

/**
 Minimal client for the AppleSMC user client.

 The SMCKeyData_t struct is 80 bytes. Fields are written and read by explicit byte offset,
 so the code does not depend on Swift's struct layout:
   0  key (UInt32, four-character code)
   28 keyInfo.dataSize (UInt32), 32 keyInfo.dataType (UInt32), 36 keyInfo.dataAttributes
   40 result (UInt8), 42 data8 (command), 44 data32 (index), 48..79 bytes

 Not thread-safe. The owner serializes calls, see `SMCThermalSource`.
 */
final class AppleSMCConnection {
    /// What the thermal source needs from the SMC. A seam so the cached-key read path can be tested without hardware.
    protocol KeyReading: AnyObject {
        /// Reads a key's declared type and size.
        func keyInfo(_ key: String) -> AppleSMCConnection.KeyInfo?
        /// Reads a key's raw bytes using key info obtained earlier.
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

    /**
     Opens a connection to the AppleSMC service.

     - Returns: The connection, or nil when AppleSMC is missing or cannot be opened, for example in a sandboxed build.
     */
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

    /// The declared size and four-character type of an SMC key, read once and then reused.
    struct KeyInfo {
        /// Size of the value in bytes. Valid sizes are 1 through 32.
        let size: Int
        /// Four-character data type, for example `flt ` or `sp78`.
        let type: String
    }

    /**
     Reads a key's declared type and size.

     - Parameters:
       - key: A four-character SMC key name, for example `TC0P`.
     - Returns: The key info, or nil when the name is not four ASCII bytes, the call fails, or the size is outside
       1 through 32 bytes.
     */
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

    /**
     Reads a key's raw bytes, including its declared type. Looks up the key info first.

     - Parameters:
       - key: A four-character SMC key name.
     - Returns: The declared type and the value bytes, or nil when the read fails.
     */
    func read(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard let info = keyInfo(key) else { return nil }
        return read(key, info: info)
    }

    /**
     Reads a key's raw bytes using key info obtained earlier, such as at probe time. Skips the key-info lookup.

     - Parameters:
       - key: A four-character SMC key name.
       - info: The key's size and type, from `keyInfo(_:)`.
     - Returns: The declared type and the value bytes, or nil when the read fails.
     */
    func read(_ key: String, info: KeyInfo) -> (type: String, bytes: [UInt8])? {
        guard let code = Self.fourCC(key) else { return nil }
        var input = Self.emptyStruct()
        Self.writeU32(&input, 0, code)
        Self.writeU32(&input, 28, UInt32(info.size))
        input[42] = Selector.readBytes
        guard let output = call(input), output[40] == 0 else { return nil }
        return (info.type, Array(output[48..<(48 + info.size)]))
    }

    /**
     Reads the number of keys in the SMC, from the `#KEY` key.

     - Returns: The key count, or nil when the value is missing or outside `0...maxKeyCount`.
     */
    func keyCount() -> Int? {
        guard let entry = read("#KEY"),
              let value = SMCDecoder.decode(type: entry.type, bytes: entry.bytes) else { return nil }
        return Self.integerCount(value, max: Self.maxKeyCount)
    }

    /**
     Converts a decoded SMC number to a count.

     `Int(Double)` traps on NaN, infinity, negatives and values beyond the range, so those are rejected first.

     - Parameters:
       - value: The decoded number.
       - max: The largest count accepted.
     - Returns: The value rounded to the nearest integer, or nil when it is out of range.
     */
    static func integerCount(_ value: Double, max: Int) -> Int? {
        guard value.isFinite, value >= 0, value <= Double(max) else { return nil }
        return Int(value.rounded())
    }

    /**
     Reads the name of the key at a given index, used to enumerate sensors.

     - Parameters:
       - index: Zero-based index into the SMC key table.
     - Returns: The four-character key name, or nil when the call fails.
     */
    func key(atIndex index: Int) -> String? {
        var input = Self.emptyStruct()
        input[42] = Selector.keyFromIndex
        Self.writeU32(&input, 44, UInt32(index))
        guard let output = call(input), output[40] == 0 else { return nil }
        return Self.string(fourCC: Self.readU32(output, 0))
    }

    /**
     Sends one SMCKeyData_t struct to the kernel and returns the output struct.

     - Parameters:
       - input: The 80-byte input struct.
     - Returns: The 80-byte output struct, or nil when the IOKit call fails.
     */
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

    /// Returns a zeroed buffer the size of the SMC struct.
    private static func emptyStruct() -> [UInt8] {
        [UInt8](repeating: 0, count: structSize)
    }

    /**
     Converts a four-character key name to its big-endian code.

     For example, `TC0P` becomes `0x54433050`.

     - Parameters:
       - key: The key name.
     - Returns: The code, or nil unless the string is exactly 4 ASCII bytes.
     */
    static func fourCC(_ key: String) -> UInt32? {
        let bytes = Array(key.utf8)
        guard bytes.count == 4 else { return nil }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    /**
     Converts a big-endian four-character code back to its key name.

     - Parameters:
       - value: The code.
     - Returns: The key name, or an empty string when the bytes are not valid UTF-8.
     */
    static func string(fourCC value: UInt32) -> String {
        let bytes = [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /**
     Writes a 32-bit value into the buffer in native byte order, matching the layout the SMC driver expects.

     Native order is little-endian on every supported Mac.

     - Parameters:
       - buffer: The struct buffer to write into.
       - offset: Byte offset of the field.
       - value: The value to store.
     */
    private static func writeU32(_ buffer: inout [UInt8], _ offset: Int, _ value: UInt32) {
        buffer[offset] = UInt8(value & 0xFF)
        buffer[offset + 1] = UInt8((value >> 8) & 0xFF)
        buffer[offset + 2] = UInt8((value >> 16) & 0xFF)
        buffer[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    /**
     Reads a 32-bit value from the buffer in native (little-endian) byte order.

     - Parameters:
       - buffer: The struct buffer to read from.
       - offset: Byte offset of the field.
     - Returns: The value stored at that offset.
     */
    private static func readU32(_ buffer: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
            | UInt32(buffer[offset + 2]) << 16 | UInt32(buffer[offset + 3]) << 24
    }
}

extension AppleSMCConnection: AppleSMCConnection.KeyReading {}
