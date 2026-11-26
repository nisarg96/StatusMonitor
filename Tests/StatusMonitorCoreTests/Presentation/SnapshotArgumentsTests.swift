import Testing
@testable import StatusMonitorCore

@Suite("SnapshotArguments")
struct SnapshotArgumentsTests {
    private func parse(_ tail: String...) -> Result<String?, SnapshotArgumentError> {
        SnapshotArguments.parse(["StatusMonitor"] + tail)
    }

    @Test("flag absent means no snapshot was requested")
    func flagAbsent() {
        #expect(parse() == .success(nil))
        #expect(SnapshotArguments.parse(["StatusMonitor", "--dump-samples", "5"]) == .success(nil))
    }

    @Test("the folder after the flag is returned as written")
    func folderReturned() {
        #expect(parse("--snapshot", "docs/images") == .success("docs/images"))
        #expect(parse("--snapshot", "/tmp/shots") == .success("/tmp/shots"))
    }

    @Test("a bare flag with no folder is rejected")
    func bareFlagRejected() {
        #expect(parse("--snapshot") == .failure(.missingFolder))
    }

    @Test("an empty folder value is rejected")
    func emptyFolderRejected() {
        #expect(parse("--snapshot", "") == .failure(.missingFolder))
    }

    @Test("another flag in the folder position is rejected, not taken as a folder")
    func nextFlagRejected() {
        #expect(parse("--snapshot", "--dump-samples") == .failure(.missingFolder))
        #expect(parse("--snapshot", "--snapshot", "docs/images") == .failure(.missingFolder))
    }

    @Test("the error message names the folder and carries the usage line")
    func errorHasUsage() {
        let message = SnapshotArgumentError.missingFolder.message
        #expect(message.contains("folder"))
        #expect(message.contains(SnapshotArguments.usage))
        #expect(SnapshotArguments.usage == "Usage: StatusMonitor --snapshot <folder>")
    }
}
