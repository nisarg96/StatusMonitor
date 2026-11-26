import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("Child process deadlines")
struct ProcessDeadlineTests {
    @Test("a sudo check that never returns is killed after its deadline")
    func sudoCheckDeadline() {
        let started = Date()
        let status = SudoersPurgeExecutor.run(executable: "/bin/sleep", arguments: ["30"], timeout: 0.5)
        #expect(status == -1)
        #expect(Date().timeIntervalSince(started) < 10)
    }

    @Test("a command that finishes before its deadline returns its exit code")
    func inTimeReturnsStatus() {
        #expect(SudoersPurgeExecutor.run(executable: "/usr/bin/true", arguments: [], timeout: 5) == 0)
        #expect(SudoersPurgeExecutor.run(executable: "/usr/bin/false", arguments: [], timeout: 5) == 1)
    }

    @Test("memory_pressure that never returns is killed after its deadline")
    func memoryPressureDeadline() {
        let started = Date()
        let command = MemoryPressureCommand(executablePath: "/bin/sleep", arguments: ["30"], timeout: 0.5)
        #expect(command.run() == -1)
        #expect(Date().timeIntervalSince(started) < 10)
    }
}
