import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("RecentCleanRows")
struct RecentCleanRowsTests {
    private let mib: Int64 = 1024 * 1024
    private let gib: Int64 = 1024 * 1024 * 1024

    private func outcome(_ preset: CleanPreset, delta: Int64?, skipped: String? = nil) -> CleanOutcome {
        // A step's delta is after − before, so a negative delta is modelled by "before" being the larger reading.
        let steps: [CleanStep] = delta.map { value in
            let before: UInt64 = value < 0 ? UInt64(-value) : 0
            let after: UInt64 = value < 0 ? 0 : UInt64(value)
            return [CleanStep(name: "purge", exitCode: 0, availableBeforeBytes: before, availableAfterBytes: after)]
        } ?? []
        return CleanOutcome(preset: preset, trigger: "manual", skippedReason: skipped, steps: steps)
    }

    @Test("freed is shown in MB under a GiB and GB above")
    func freedLabel() {
        #expect(RecentCleanRows.freedLabel(outcome(.standard, delta: 512 * mib)) == "512 MB")
        #expect(RecentCleanRows.freedLabel(outcome(.standard, delta: 3 * gib / 2)) == "1.5 GB")
    }

    @Test("a negative delta is shown as nothing freed, not a negative number")
    func negativeDelta() {
        #expect(RecentCleanRows.freedLabel(outcome(.standard, delta: -mib)) == "0 MB")
    }

    @Test("skipped or unmeasured cleans show a dash")
    func dashes() {
        #expect(RecentCleanRows.freedLabel(outcome(.extreme, delta: nil)) == "—")
        #expect(RecentCleanRows.freedLabel(outcome(.standard, delta: 5 * mib, skipped: "helper not available")) == "—")
    }

    @Test("type names are Standard and Extreme")
    func typeLabels() {
        #expect(RecentCleanRows.typeLabel(.standard) == "Standard")
        #expect(RecentCleanRows.typeLabel(.extreme) == "Extreme")
    }

    @Test("rows keep the order given, with time from the injected formatter")
    func rows() {
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 200)
        let cleans = [
            RecentClean(date: late, outcome: outcome(.extreme, delta: gib)),
            RecentClean(date: early, outcome: outcome(.standard, delta: nil))
        ]
        let rows = RecentCleanRows.rows(cleans) { $0 == late ? "10:00" : "09:00" }
        #expect(rows == [
            RecentCleanRow(time: "10:00", type: "Extreme", freed: "1.0 GB"),
            RecentCleanRow(time: "09:00", type: "Standard", freed: "—")
        ])
    }
}
