import Testing
@testable import StatusMonitorCore

@Suite("SettingsItemPresentation")
struct SettingsItemPresentationTests {
    @Test("style labels use the spec's names")
    func styleLabels() {
        #expect(SettingsItemPresentation.styleLabel(.grouped) == "Grouped")
        #expect(SettingsItemPresentation.styleLabel(.icon) == "Icon only")
        #expect(SettingsItemPresentation.styleLabel(.value) == "Value")
    }

    @Test("chips are the six styles, plus icon only for memory pressure")
    func chips() {
        let six: [MenuBarItemStyle] = [.value, .stacked, .bars, .sparkline, .ring, .grouped]
        #expect(SettingsItemPresentation.chipStyles(for: .network) == six)
        #expect(SettingsItemPresentation.chipStyles(for: .memoryPressure) == six + [.icon])
    }

    @Test("alert units: MB/s for rates, degrees for temperature, percent otherwise")
    func alertUnits() {
        #expect(SettingsItemPresentation.alertUnit(for: .network) == "MB/s")
        #expect(SettingsItemPresentation.alertUnit(for: .disk) == "MB/s")
        #expect(SettingsItemPresentation.alertUnit(for: .thermal) == "°C")
        #expect(SettingsItemPresentation.alertUnit(for: .cpu) == "%")
    }

    @Test("idle threshold converts with 1024 steps, matching the rate formatter")
    func idleUnits() {
        #expect(SettingsItemPresentation.idleKB(fromBytes: 102_400) == 100)
        #expect(SettingsItemPresentation.idleBytes(fromKB: 100) == 102_400)
        #expect(SettingsItemPresentation.idleBytes(fromKB: -5) == 0)
    }

    @Test("only network and disk offer hide-when-idle")
    func idleOffered() {
        #expect(SettingsItemPresentation.offersHideWhenIdle(.network))
        #expect(SettingsItemPresentation.offersHideWhenIdle(.disk))
        #expect(!SettingsItemPresentation.offersHideWhenIdle(.cpu))
    }

    @Test("the list leaves out RAM, which is merged into CPU")
    func listedItems() {
        let listed = SettingsItemPresentation.listedItems(order: [.cpu, .ram, .gpu])
        #expect(listed == [.cpu, .gpu])
    }

    @Test("moving a row reorders the list, and RAM stays last")
    func reorder() {
        let order: [MetricItemID] = [.cpu, .gpu, .network, .ram]
        let moved = SettingsItemPresentation.reordered(order, moving: [0], to: 3)
        #expect(moved == [.gpu, .network, .cpu, .ram])
    }

    @Test("moving several rows keeps their relative order")
    func reorderMany() {
        let order: [MetricItemID] = [.cpu, .gpu, .network, .disk, .ram]
        let moved = SettingsItemPresentation.reordered(order, moving: [0, 1], to: 4)
        #expect(moved == [.network, .disk, .cpu, .gpu, .ram])
    }

    @Test("priority labels are High, Medium and Low")
    func priorityLabels() {
        #expect(MenuBarPriority.allCases.map(\.label) == ["High", "Medium", "Low"])
    }
}
