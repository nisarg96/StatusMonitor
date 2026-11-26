import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("MenuBarItemConfig decoding")
struct MenuBarItemConfigDecodeTests {
    @Test("a saved config with a legacy refresh key still decodes, and the key is ignored")
    func legacyRefreshKeyIgnored() throws {
        let json = """
        {"style":"ring","refresh":5,"hideWhenIdle":true,"idleBelow":250000,"alertAbove":90,"onClick":"nothing"}
        """
        let config = try JSONDecoder().decode(MenuBarItemConfig.self, from: Data(json.utf8))

        #expect(config.style == .ring)
        #expect(config.hideWhenIdle == true)
        #expect(config.idleBelow == 250_000)
        #expect(config.alertAbove == 90)
        #expect(config.onClick == .nothing)
    }
}
