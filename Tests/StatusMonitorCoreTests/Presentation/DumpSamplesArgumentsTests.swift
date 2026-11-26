import Testing
@testable import StatusMonitorCore

@Suite("DumpSamplesArguments")
struct DumpSamplesArgumentsTests {
    private func parse(_ tail: String...) -> Result<Int?, DumpSamplesArgumentError> {
        DumpSamplesArguments.parse(["StatusMonitor"] + tail)
    }

    @Test("flag absent means the dump was not requested")
    func flagAbsent() {
        #expect(parse() == .success(nil))
        #expect(DumpSamplesArguments.parse(["StatusMonitor", "--other", "5"]) == .success(nil))
    }

    @Test("a positive count within range is returned")
    func validCounts() {
        #expect(parse("--dump-samples", "10") == .success(10))
        #expect(parse("--dump-samples", "1") == .success(1))
        #expect(parse("--dump-samples", "1000") == .success(1000))
    }

    @Test("zero is rejected")
    func zeroRejected() {
        #expect(parse("--dump-samples", "0") == .failure(.outOfRange))
    }

    @Test("negative numbers are rejected")
    func negativeRejected() {
        #expect(parse("--dump-samples", "-3") == .failure(.outOfRange))
    }

    @Test("non-numeric values are rejected")
    func nonNumericRejected() {
        #expect(parse("--dump-samples", "abc") == .failure(.notAnInteger))
    }

    @Test("a bare flag keeps the documented default of 10 samples")
    func bareFlagUsesDefault() {
        #expect(parse("--dump-samples") == .success(10))
    }

    @Test("values above 1000 are rejected")
    func aboveMaximumRejected() {
        #expect(parse("--dump-samples", "1001") == .failure(.outOfRange))
    }

    @Test("every error carries a usage message")
    func errorsHaveUsage() {
        #expect(DumpSamplesArgumentError.notAnInteger.message.contains("1...1000"))
        #expect(DumpSamplesArgumentError.outOfRange.message.contains("1...1000"))
    }
}
