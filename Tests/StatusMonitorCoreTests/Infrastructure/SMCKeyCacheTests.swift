import Testing
@testable import StatusMonitorCore

@Suite("SMC key cache and numeric bounds")
struct SMCKeyCacheTests {
    /// Stands in for the SMC. Counts key-info lookups, which are the per-read cost the cache removes.
    final class CountingKeyReader: AppleSMCConnection.KeyReading {
        private(set) var keyInfoLookups = 0
        var valueBytes: [UInt8] = [0x3E, 0x80]   // sp78 = 62.5

        func keyInfo(_ key: String) -> AppleSMCConnection.KeyInfo? {
            keyInfoLookups += 1
            return nil
        }

        func read(_ key: String, info: AppleSMCConnection.KeyInfo) -> (type: String, bytes: [UInt8])? {
            (info.type, valueBytes)
        }
    }

    @Test("reads use the key info cached at probe time, with no per-read lookup")
    func readsUseCachedInfo() {
        let reader = CountingKeyReader()
        let sensor = SMCThermalSource.Sensor(key: "TC0P", info: .init(size: 2, type: "sp78"))
        let reading = SMCThermalSource.read(reader, temperatures: [sensor], fans: [])
        #expect(reading?.cpuTemperatureC == 62.5)
        #expect(reader.keyInfoLookups == 0)
    }

    @Test("an out-of-range fan rpm is skipped instead of trapping in Int(Double)")
    func hugeFanRpmSkipped() {
        let reader = CountingKeyReader()
        // 1e30 as a little-endian float: finite, but far too large to be an Int.
        let bits = Float(1e30).bitPattern
        reader.valueBytes = (0..<4).map { UInt8((bits >> (8 * UInt32($0))) & 0xFF) }
        let fan = SMCThermalSource.Sensor(key: "F0Ac", info: .init(size: 4, type: "flt "))
        let reading = SMCThermalSource.read(reader, temperatures: [], fans: [(index: 0, sensor: fan)])
        #expect(reading == nil)
    }

    @Test("integer counts reject NaN, infinity, negatives and values above the bound")
    func integerCountBounds() {
        #expect(AppleSMCConnection.integerCount(.nan, max: 16) == nil)
        #expect(AppleSMCConnection.integerCount(.infinity, max: 16) == nil)
        #expect(AppleSMCConnection.integerCount(-1, max: 16) == nil)
        #expect(AppleSMCConnection.integerCount(1e30, max: 16) == nil)
        #expect(AppleSMCConnection.integerCount(17, max: 16) == nil)
        #expect(AppleSMCConnection.integerCount(2, max: 16) == 2)
    }
}
