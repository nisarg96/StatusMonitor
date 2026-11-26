import Foundation

/// One executed step of a clean, with its exit code and the available-memory delta it produced.
public struct CleanStep: Equatable, Sendable {
    public let name: String
    public let exitCode: Int32?
    public let availableBeforeBytes: UInt64?
    public let availableAfterBytes: UInt64?

    /// Change in available memory across this step. Nil when either reading is missing. Never estimated.
    public var deltaBytes: Int64? {
        guard let before = availableBeforeBytes, let after = availableAfterBytes else { return nil }
        return Int64(bitPattern: after &- before)
    }
}

/// Result of one clean attempt. A skipped attempt has no steps and carries the reason.
public struct CleanOutcome: Equatable, Sendable {
    public let preset: CleanPreset
    public let trigger: String
    public let skippedReason: String?
    public let steps: [CleanStep]

    /// Total change from before the first step to after the last. Nil when skipped or unmeasurable.
    public var totalDeltaBytes: Int64? {
        guard skippedReason == nil,
              let first = steps.first?.availableBeforeBytes,
              let last = steps.last?.availableAfterBytes else { return nil }
        return Int64(bitPattern: last &- first)
    }
}

/// Runs Standard and Extreme Clean. Each step is measured and logged, so reported deltas are real measurements.
public final class MemoryCleanUseCase {
    private let purge: PrivilegedPurgeExecutor
    private let pressure: MemoryPressureRunner
    private let memory: AvailableMemorySource
    private let log: RemediationLogWriter
    private let now: () -> Date

    public init(
        purge: PrivilegedPurgeExecutor,
        pressure: MemoryPressureRunner,
        memory: AvailableMemorySource,
        log: RemediationLogWriter,
        now: @escaping () -> Date = Date.init
    ) {
        self.purge = purge
        self.pressure = pressure
        self.memory = memory
        self.log = log
        self.now = now
    }

    /// Standard Clean: purge inactive file-backed memory. It does not free wired memory or stop runaway processes.
    public func clean(_ preset: CleanPreset, trigger: String) -> CleanOutcome {
        guard purge.isAvailable() else {
            return logged(CleanOutcome(
                preset: preset, trigger: trigger,
                skippedReason: "helper not available", steps: []
            ))
        }

        switch preset {
        case .standard:
            let step = measured(name: "purge") { purge.purge() }
            return logged(CleanOutcome(preset: preset, trigger: trigger, skippedReason: nil, steps: [step]))

        case .extreme:
            // Extreme: purge, then memory_pressure -l warn, then a second purge. Each step is measured separately.
            let first = measured(name: "purge") { purge.purge() }
            let middle = measured(name: "memory_pressure -l warn") { pressure.run() }
            let second = measured(name: "purge (second pass)") { purge.purge() }
            return logged(CleanOutcome(
                preset: preset, trigger: trigger, skippedReason: nil,
                steps: [first, middle, second]
            ))
        }
    }

    private func measured(name: String, _ action: () -> Int32) -> CleanStep {
        let before = memory.readAvailableBytes()
        let exitCode = action()
        let after = memory.readAvailableBytes()
        return CleanStep(name: name, exitCode: exitCode, availableBeforeBytes: before, availableAfterBytes: after)
    }

    private func logged(_ outcome: CleanOutcome) -> CleanOutcome {
        let message: String
        if let reason = outcome.skippedReason {
            message = "skipped: \(reason) [\(outcome.preset.rawValue), trigger: \(outcome.trigger)]"
        } else {
            let steps = outcome.steps.map { step -> String in
                let exit = step.exitCode.map(String.init) ?? "n/a"
                let delta = step.deltaBytes.map { "\($0) bytes" } ?? "unmeasured"
                return "\(step.name) exit=\(exit) delta=\(delta)"
            }
            let total = outcome.totalDeltaBytes.map { "\($0) bytes" } ?? "unmeasured"
            message = "clean \(outcome.preset.rawValue) [trigger: \(outcome.trigger)] total delta=\(total); "
                + steps.joined(separator: "; ")
        }
        log.write(RemediationLogEntry(timestamp: now(), message: message))
        return outcome
    }
}
