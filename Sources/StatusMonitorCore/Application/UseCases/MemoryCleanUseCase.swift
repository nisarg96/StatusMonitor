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
///
/// One instance is shared by Auto Clean and the Clean now buttons. Its clean slot allows one clean at a time: a clean
/// that starts while another runs returns a skipped outcome.
public final class MemoryCleanUseCase {
    private let purge: PrivilegedPurgeExecutor
    private let pressure: MemoryPressureRunner
    private let memory: AvailableMemorySource
    private let log: RemediationLogWriter
    private let now: () -> Date
    /// Called with the epoch second of each clean that ran (skips excluded). The composition root stores it as the
    /// last-clean time, so the Auto Clean cooldown counts from manual cleans too.
    private let recordClean: (Double) -> Void

    /// Guards `cleanRunning` and `executedCleans`. Read and written from any thread.
    private let slotLock = NSLock()
    private var cleanRunning = false
    private var executedCleans = 0

    public init(
        purge: PrivilegedPurgeExecutor,
        pressure: MemoryPressureRunner,
        memory: AvailableMemorySource,
        log: RemediationLogWriter,
        now: @escaping () -> Date = Date.init,
        recordClean: @escaping (Double) -> Void = { _ in }
    ) {
        self.purge = purge
        self.pressure = pressure
        self.memory = memory
        self.log = log
        self.now = now
        self.recordClean = recordClean
    }

    /// True while a clean holds the slot.
    public var isCleaning: Bool {
        slotLock.lock()
        defer { slotLock.unlock() }
        return cleanRunning
    }

    /// The number of cleans that ran, skips excluded. Auto Clean compares it between ticks to notice a manual clean.
    public var executedCleanCount: Int {
        slotLock.lock()
        defer { slotLock.unlock() }
        return executedCleans
    }

    /// Takes the shared clean slot. Returns false when a clean is already running. Each true return must be followed
    /// by exactly one `runReservedClean`, which gives the slot back.
    public func reserveCleanSlot() -> Bool {
        slotLock.lock()
        defer { slotLock.unlock() }
        guard !cleanRunning else { return false }
        cleanRunning = true
        return true
    }

    /// Runs a clean. Returns a skipped outcome, with no steps, when another clean is running.
    public func clean(_ preset: CleanPreset, trigger: String) -> CleanOutcome {
        guard reserveCleanSlot() else {
            return logged(CleanOutcome(
                preset: preset, trigger: trigger,
                skippedReason: "a clean is already running", steps: []
            ))
        }
        return runReservedClean(preset, trigger: trigger)
    }

    /// Runs a clean whose slot the caller reserved with `reserveCleanSlot`. The slot is released when this returns.
    public func runReservedClean(_ preset: CleanPreset, trigger: String) -> CleanOutcome {
        defer { releaseCleanSlot() }
        guard purge.isAvailable() else {
            return logged(CleanOutcome(
                preset: preset, trigger: trigger,
                skippedReason: "helper not available", steps: []
            ))
        }
        let steps = executeSteps(preset)
        recordCleanRan()
        return logged(CleanOutcome(preset: preset, trigger: trigger, skippedReason: nil, steps: steps))
    }

    private func executeSteps(_ preset: CleanPreset) -> [CleanStep] {
        switch preset {
        case .standard:
            // Standard: purge inactive file-backed memory. It does not free wired memory or stop runaway processes.
            return [measured(name: "purge") { purge.purge() }]
        case .extreme:
            // Extreme: purge, then memory_pressure -l warn, then a second purge. Each step is measured separately.
            return [
                measured(name: "purge") { purge.purge() },
                measured(name: "memory_pressure -l warn") { pressure.run() },
                measured(name: "purge (second pass)") { purge.purge() }
            ]
        }
    }

    private func recordCleanRan() {
        recordClean(now().timeIntervalSince1970)
        slotLock.lock()
        executedCleans += 1
        slotLock.unlock()
    }

    private func releaseCleanSlot() {
        slotLock.lock()
        cleanRunning = false
        slotLock.unlock()
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
