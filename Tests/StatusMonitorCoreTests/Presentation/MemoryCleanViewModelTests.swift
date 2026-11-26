import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("MemoryCleanViewModel")
struct MemoryCleanViewModelTests {
    /// Runs the work inline, so the tests see the final state without waiting.
    private let inline: MemoryCleanViewModel.Runner = { work, done in done(work()) }

    private func outcome(_ preset: CleanPreset) -> CleanOutcome {
        CleanOutcome(preset: preset, trigger: "manual", skippedReason: nil, steps: [])
    }

    @Test("a clean runs the action for that preset and records it, newest first")
    func recordsNewestFirst() {
        var clock = Date(timeIntervalSince1970: 1)
        let model = MemoryCleanViewModel(clean: { self.outcome($0) }, now: { clock }, runner: inline)
        model.clean(.standard)
        clock = Date(timeIntervalSince1970: 2)
        model.clean(.extreme)
        #expect(model.recent.map(\.outcome.preset) == [.extreme, .standard])
        #expect(model.recent.first?.date == Date(timeIntervalSince1970: 2))
        #expect(model.isCleaning == false)
    }

    @Test("the list keeps only the most recent entries")
    func capsList() {
        let model = MemoryCleanViewModel(clean: { self.outcome($0) }, runner: inline)
        for _ in 0..<(MemoryCleanViewModel.maxRecent + 3) {
            model.clean(.standard)
        }
        #expect(model.recent.count == MemoryCleanViewModel.maxRecent)
    }

    @Test("a second clean is ignored while one is running")
    func ignoresReentry() {
        var calls = 0
        var pending: (() -> Void)?
        let deferred: MemoryCleanViewModel.Runner = { work, done in
            pending = { done(work()) }
        }
        let model = MemoryCleanViewModel(clean: { preset in calls += 1; return self.outcome(preset) }, runner: deferred)
        model.clean(.standard)
        #expect(model.isCleaning)
        model.clean(.extreme)
        pending?()
        #expect(calls == 1)
        #expect(model.isCleaning == false)
        #expect(model.recent.count == 1)
    }
}
