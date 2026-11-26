import Testing
@testable import StatusMonitorCore

@Suite("SettingsSidebarItem")
struct SettingsSidebarItemTests {
    @Test("the three live panes are in sidebar order and have titles")
    func livePanes() {
        #expect(SettingsPane.allCases == [.menuBarItems, .general, .memoryClean])
        #expect(SettingsPane.menuBarItems.title == "Menu bar items")
        #expect(SettingsPane.general.title == "General")
        #expect(SettingsPane.memoryClean.title == "Memory Clean")
    }

    @Test("coming-later rows are Sampling, Alerts and About")
    func comingLater() {
        #expect(SettingsSidebarItem.comingLaterTitles == ["Sampling", "Alerts", "About"])
    }

    @Test("clicking a pane selects it")
    func selectsPane() {
        #expect(SettingsSidebarItem.resolve(current: .general, tapped: .pane(.memoryClean)) == .memoryClean)
    }

    @Test("clicking a coming-later row leaves the current pane selected")
    func comingLaterIsNotSelectable() {
        let tapped = SettingsSidebarItem.comingLater("Alerts")
        #expect(SettingsSidebarItem.resolve(current: .menuBarItems, tapped: tapped) == .menuBarItems)
        #expect(SettingsSidebarItem.resolve(current: .general, tapped: tapped) == .general)
    }
}
