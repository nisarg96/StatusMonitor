import Testing
@testable import StatusMonitorCore

@Suite("ByteCountFormat")
struct ByteCountFormatTests {
    @Test("small totals stay in bytes or kilobytes, never rounded to 0.0 GB")
    func smallTotals() {
        #expect(ByteCountFormat.text(0) == "0 B")
        #expect(ByteCountFormat.text(512) == "512 B")
        #expect(ByteCountFormat.text(340 * 1024) == "340.0 KB")
    }

    @Test("larger totals use 1024 steps up to GB")
    func largeTotals() {
        #expect(ByteCountFormat.text(1.5 * 1024 * 1024) == "1.5 MB")
        #expect(ByteCountFormat.text(3 * 1024 * 1024 * 1024) == "3.0 GB")
    }

    @Test("negative input is clamped to zero")
    func negative() {
        #expect(ByteCountFormat.text(-5) == "0 B")
    }
}
