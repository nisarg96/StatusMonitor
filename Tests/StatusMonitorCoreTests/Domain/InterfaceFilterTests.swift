import Testing
@testable import StatusMonitorCore

@Suite("InterfaceFilter")
struct InterfaceFilterTests {
    private let down = InterfaceCounters(name: "en1", isUp: false, isRunning: false, isLoopback: false, rxBytes: 0, txBytes: 0)
    private let notRunning = InterfaceCounters(name: "en2", isUp: true, isRunning: false, isLoopback: false, rxBytes: 0, txBytes: 0)

    @Test("standard policy keeps only up, running, non-loopback interfaces")
    func standardPolicy() {
        #expect(InterfaceFilter.standard.includes(.active("en0")))
        #expect(!InterfaceFilter.standard.includes(.loopback()))
        #expect(!InterfaceFilter.standard.includes(down))
        #expect(!InterfaceFilter.standard.includes(notRunning))
    }

    @Test("settings default excludes loopback and inactive interfaces")
    func defaultSettings() {
        let filter = InterfaceFilter.from(MetricSettings())
        #expect(filter.includes(.active("en0")))
        #expect(!filter.includes(.loopback()))
        #expect(!filter.includes(down))
    }

    @Test("includeLoopback lets lo0 through but still drops inactive interfaces")
    func includeLoopback() {
        let filter = InterfaceFilter.from(MetricSettings(includeLoopback: true))
        #expect(filter.includes(.loopback()))
        #expect(!filter.includes(down))
    }

    @Test("allow-list restricts to the named interfaces")
    func allowList() {
        let filter = InterfaceFilter.from(MetricSettings(allowedInterfaces: ["utun3"]))
        #expect(filter.includes(.active("utun3")))
        #expect(!filter.includes(.active("en0")))
    }
}
