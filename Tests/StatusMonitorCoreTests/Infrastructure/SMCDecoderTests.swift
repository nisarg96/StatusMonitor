import Testing
@testable import StatusMonitorCore

@Suite("SMCDecoder")
struct SMCDecoderTests {
    @Test("flt is a little-endian IEEE float (1.0 = 00 00 80 3F)")
    func floatLittleEndian() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0x00, 0x80, 0x3F]) == 1.0)
    }

    @Test("sp78 is signed 8.8 big-endian (0x3E80 = 62.5)")
    func sp78() {
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0x3E, 0x80]) == 62.5)
    }

    @Test("sp78 handles negative values")
    func sp78Negative() {
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0xFF, 0x80]) == -0.5)
    }

    @Test("fpe2 is unsigned 14.2 big-endian (0x1F40 = 2000 RPM)")
    func fpe2() {
        #expect(SMCDecoder.decode(type: "fpe2", bytes: [0x1F, 0x40]) == 2000)
    }

    @Test("integer types decode big-endian")
    func integers() {
        #expect(SMCDecoder.decode(type: "ui8 ", bytes: [0x02]) == 2)
        #expect(SMCDecoder.decode(type: "ui16", bytes: [0x01, 0x00]) == 256)
        #expect(SMCDecoder.decode(type: "ui32", bytes: [0x00, 0x00, 0x01, 0x00]) == 256)
    }

    @Test("an unknown type is skipped, not guessed")
    func unknownTypeIsNil() {
        #expect(SMCDecoder.decode(type: "xyz ", bytes: [1, 2, 3, 4]) == nil)
    }

    @Test("too few bytes for the declared type is nil, never a partial value")
    func truncatedIsNil() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0x00]) == nil)
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0x3E]) == nil)
    }

    @Test("a NaN float bit pattern is rejected")
    func nanRejected() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0x00, 0xC0, 0x7F]) == nil)
    }
}

@Suite("TemperatureSelector")
struct TemperatureSelectorTests {
    @Test("picks the hottest plausible reading")
    func hottestPlausible() {
        #expect(TemperatureSelector.hottestPlausible([41, 58.5, 49]) == 58.5)
    }

    @Test("implausible readings (sensor fault or unset) are ignored")
    func implausibleIgnored() {
        #expect(TemperatureSelector.hottestPlausible([0, 2, 300]) == nil)
        #expect(TemperatureSelector.hottestPlausible([0, 2, 300, 44]) == 44)
    }

    @Test("no readings means no temperature, not zero")
    func emptyIsNil() {
        #expect(TemperatureSelector.hottestPlausible([]) == nil)
    }

    @Test("only CPU-prefixed sensor keys are considered")
    func cpuKeyPrefixes() {
        #expect(TemperatureSelector.isCPUSensorKey("TC0P"))
        #expect(TemperatureSelector.isCPUSensorKey("Tp09"))
        #expect(!TemperatureSelector.isCPUSensorKey("TB1T"))
        #expect(!TemperatureSelector.isCPUSensorKey("F0Ac"))
    }
}

@Suite("AppleSMCConnection four-character codes")
struct FourCCTests {
    @Test("four-character codes encode big-endian and round-trip")
    func roundTrip() {
        let code = AppleSMCConnection.fourCC("TC0P")
        #expect(code == 0x5443_3050)
        #expect(code.map { AppleSMCConnection.string(fourCC: $0) } == "TC0P")
    }

    @Test("keys that are not exactly four bytes are rejected")
    func wrongLength() {
        #expect(AppleSMCConnection.fourCC("TC0") == nil)
        #expect(AppleSMCConnection.fourCC("TC0PX") == nil)
    }
}
