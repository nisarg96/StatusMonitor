import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("PopoverCleanLine")
struct PopoverCleanLineTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    private func clean(freedBytes: Int64?, minutesAgo: Double, skipped: String? = nil) -> RecentClean {
        let step = CleanStep(
            name: "purge", exitCode: 0,
            availableBeforeBytes: 0,
            availableAfterBytes: freedBytes.map { UInt64($0) }
        )
        let outcome = CleanOutcome(
            preset: .standard, trigger: "manual", skippedReason: skipped,
            steps: freedBytes == nil && skipped == nil ? [] : [step]
        )
        return RecentClean(date: now.addingTimeInterval(-minutesAgo * 60), outcome: outcome)
    }

    @Test("no clean yet means no line at all")
    func noClean() {
        #expect(PopoverCleanLine.text(latest: nil, now: now) == nil)
    }

    @Test("a measured clean shows what it freed and how many minutes ago")
    func measured() {
        let text = PopoverCleanLine.text(latest: clean(freedBytes: 1_288_490_188, minutesAgo: 4.2), now: now)
        #expect(text == "Last clean freed 1.2 GB, 4 min ago")
    }

    @Test("a skipped clean has no line, never a zero")
    func skipped() {
        let latest = clean(freedBytes: nil, minutesAgo: 1, skipped: "helper not available")
        #expect(PopoverCleanLine.text(latest: latest, now: now) == nil)
    }

    @Test("an unmeasured clean has no line")
    func unmeasured() {
        #expect(PopoverCleanLine.text(latest: clean(freedBytes: nil, minutesAgo: 1), now: now) == nil)
    }
}
