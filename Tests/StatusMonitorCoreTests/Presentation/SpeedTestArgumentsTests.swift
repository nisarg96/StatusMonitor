import Testing
@testable import StatusMonitorCore

@Suite("SpeedTestArguments")
struct SpeedTestArgumentsTests {
    @Test("the flag absent means the diagnostic was not requested")
    func flagAbsent() {
        #expect(SpeedTestArguments.isRequested(["StatusMonitor"]) == false)
        #expect(SpeedTestArguments.isRequested(["StatusMonitor", "--dump-samples", "5"]) == false)
    }

    @Test("the flag present, alone or with other arguments, requests the diagnostic")
    func flagPresent() {
        #expect(SpeedTestArguments.isRequested(["StatusMonitor", "--speed-test"]))
        #expect(SpeedTestArguments.isRequested(["StatusMonitor", "--dump-samples", "5", "--speed-test"]))
    }

    @Test("a longer flag name does not match")
    func longerFlagDoesNotMatch() {
        #expect(SpeedTestArguments.isRequested(["StatusMonitor", "--speed-test-extra"]) == false)
    }

    @Test("the program name is never read as the flag")
    func programNameIgnored() {
        #expect(SpeedTestArguments.isRequested(["--speed-test"]) == false)
    }
}
