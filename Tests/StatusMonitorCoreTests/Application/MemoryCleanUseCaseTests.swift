import Foundation
import Testing
@testable import StatusMonitorCore

final class FakePurge: PrivilegedPurgeExecutor {
    var available = true
    var purgeExitCode: Int32 = 0
    private(set) var purgeCalls = 0

    func isAvailable() -> Bool { available }

    func purge() -> Int32 {
        purgeCalls += 1
        return purgeExitCode
    }
}

final class FakePressureRunner: MemoryPressureRunner {
    var exitCode: Int32 = 0
    private(set) var runs = 0

    func run() -> Int32 {
        runs += 1
        return exitCode
    }
}

/// Returns a scripted sequence of available-memory readings, one per call.
final class ScriptedMemory: AvailableMemorySource {
    var readings: [UInt64?]

    init(_ readings: [UInt64?]) {
        self.readings = readings
    }

    func readAvailableBytes() -> UInt64? {
        guard !readings.isEmpty else { return nil }
        return readings.removeFirst()
    }
}

final class RecordingLog: RemediationLogWriter {
    private(set) var entries: [RemediationLogEntry] = []

    func write(_ entry: RemediationLogEntry) {
        entries.append(entry)
    }
}

@Suite("MemoryCleanUseCase")
struct MemoryCleanUseCaseTests {
    @Test("standard clean runs purge once and measures before and after")
    func standardMeasures() {
        let purge = FakePurge()
        let log = RecordingLog()
        let useCase = MemoryCleanUseCase(
            purge: purge, pressure: FakePressureRunner(),
            memory: ScriptedMemory([1_000, 1_600]), log: log
        )
        let outcome = useCase.clean(.standard, trigger: "manual")

        #expect(purge.purgeCalls == 1)
        #expect(outcome.skippedReason == nil)
        #expect(outcome.steps.count == 1)
        #expect(outcome.steps[0].deltaBytes == 600)
        #expect(outcome.totalDeltaBytes == 600)
    }

    @Test("a negative delta (memory consumed meanwhile) is reported as negative, not clamped")
    func negativeDelta() {
        let useCase = MemoryCleanUseCase(
            purge: FakePurge(), pressure: FakePressureRunner(),
            memory: ScriptedMemory([2_000, 1_500]), log: RecordingLog()
        )
        #expect(useCase.clean(.standard, trigger: "manual").totalDeltaBytes == -500)
    }

    @Test("an unreadable memory value makes the delta unmeasured, never zero")
    func unmeasuredDelta() {
        let useCase = MemoryCleanUseCase(
            purge: FakePurge(), pressure: FakePressureRunner(),
            memory: ScriptedMemory([nil, 500]), log: RecordingLog()
        )
        let outcome = useCase.clean(.standard, trigger: "manual")
        #expect(outcome.totalDeltaBytes == nil)
        #expect(outcome.steps[0].deltaBytes == nil)
    }

    @Test("without the helper, the clean is skipped, purge is never executed, and the skip is logged")
    func helperMissingSkips() {
        let purge = FakePurge()
        purge.available = false
        let log = RecordingLog()
        let useCase = MemoryCleanUseCase(
            purge: purge, pressure: FakePressureRunner(),
            memory: ScriptedMemory([]), log: log
        )
        let outcome = useCase.clean(.standard, trigger: "auto")

        #expect(purge.purgeCalls == 0)
        #expect(outcome.skippedReason == "helper not available")
        #expect(outcome.steps.isEmpty)
        #expect(log.entries.count == 1)
        #expect(log.entries[0].message.contains("skipped: helper not available"))
    }

    @Test("extreme clean runs purge, memory_pressure, then a second purge, each measured")
    func extremeSteps() {
        let purge = FakePurge()
        let pressure = FakePressureRunner()
        let useCase = MemoryCleanUseCase(
            purge: purge, pressure: pressure,
            memory: ScriptedMemory([100, 300, 300, 450, 450, 470]), log: RecordingLog()
        )
        let outcome = useCase.clean(.extreme, trigger: "manual")

        #expect(purge.purgeCalls == 2)
        #expect(pressure.runs == 1)
        #expect(outcome.steps.map(\.name) == ["purge", "memory_pressure -l warn", "purge (second pass)"])
        #expect(outcome.steps.map(\.deltaBytes) == [200, 150, 20])
        #expect(outcome.totalDeltaBytes == 370)
    }

    @Test("every step's exit code is recorded in the log line")
    func exitCodesLogged() {
        let purge = FakePurge()
        purge.purgeExitCode = 0
        let pressure = FakePressureRunner()
        pressure.exitCode = 3
        let log = RecordingLog()
        let useCase = MemoryCleanUseCase(
            purge: purge, pressure: pressure,
            memory: ScriptedMemory([1, 2, 2, 3, 3, 4]), log: log
        )
        _ = useCase.clean(.extreme, trigger: "manual")
        #expect(log.entries.count == 1)
        #expect(log.entries[0].message.contains("memory_pressure -l warn exit=3"))
        #expect(log.entries[0].message.contains("purge exit=0"))
    }
}
