import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("Designer defaults for menu bar styles")
struct DesignerDefaultsTests {
    @Test("network and disk are stacked; CPU, RAM, GPU and temperature are icon + value")
    func defaultStyles() {
        #expect(MenuBarItemConfig.defaults(for: .network).style == .stacked)
        #expect(MenuBarItemConfig.defaults(for: .disk).style == .stacked)
        #expect(MenuBarItemConfig.defaults(for: .cpu).style == .value)
        #expect(MenuBarItemConfig.defaults(for: .ram).style == .value)
        #expect(MenuBarItemConfig.defaults(for: .gpu).style == .value)
        #expect(MenuBarItemConfig.defaults(for: .thermal).style == .value)
    }

    @Test("memory pressure is icon only")
    func pressureIconOnly() {
        #expect(MenuBarItemConfig.defaults(for: .memoryPressure).style == .icon)
    }

    @Test("disk hides while idle by default")
    func diskHidesWhenIdle() {
        #expect(MenuBarItemConfig.defaults(for: .disk).hideWhenIdle)
        #expect(!MenuBarItemConfig.defaults(for: .network).hideWhenIdle)
    }

    @Test("a user's config overrides the designer default")
    func userConfigWins() {
        var settings = MetricSettings()
        settings.menuBarItemConfigs[.cpu] = MenuBarItemConfig(style: .ring)
        #expect(settings.itemConfig(for: .cpu).style == .ring)
        #expect(settings.itemConfig(for: .ram).style == .value)
    }
}

@Suite("Menu bar glyphs")
struct MenuBarGlyphTests {
    private let physical: UInt64 = 8 * 1_073_741_824

    @Test("memory pressure in icon style becomes an icon-only glyph carrying the level")
    func pressureGlyph() {
        var snapshot = SystemSnapshot()
        snapshot.memoryPressure = .critical
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .memoryPressure, snapshot: snapshot,
            config: MenuBarItemConfig.defaults(for: .memoryPressure),
            history: [:], physicalMemoryBytes: physical
        )
        #expect(glyph == .pressure(symbol: MetricSymbol.memoryPressure, level: .critical))
    }

    @Test("no pressure reading means no glyph, so the item shows its icon alone")
    func noPressureNoGlyph() {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .memoryPressure, snapshot: SystemSnapshot(),
            config: MenuBarItemConfig.defaults(for: .memoryPressure),
            history: [:], physicalMemoryBytes: physical
        )
        #expect(glyph == nil)
    }

    @Test("network in stacked style shows upload above download")
    func stackedNetwork() {
        let snapshot = SystemSnapshot(downBps: 340_000, upBps: 1_200_000)
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: snapshot,
            config: MenuBarItemConfig.defaults(for: .network),
            history: [:], physicalMemoryBytes: physical
        )
        guard case let .stacked(_, top, bottom, _) = glyph else {
            Issue.record("expected a stacked glyph")
            return
        }
        #expect(top.hasPrefix("↑"))
        #expect(bottom.hasPrefix("↓"))
    }

    @Test("disk is idle below its threshold and is hidden when hide-when-idle is on")
    func diskIdle() {
        let quiet = SystemSnapshot(disk: DiskRates(readBps: 10, writeBps: 10))
        #expect(MenuBarGlyphBuilder.isIdle(.disk, snapshot: quiet, config: MenuBarItemConfig.defaults(for: .disk)))

        let busy = SystemSnapshot(disk: DiskRates(readBps: 5_000_000, writeBps: 0))
        #expect(!MenuBarGlyphBuilder.isIdle(.disk, snapshot: busy, config: MenuBarItemConfig.defaults(for: .disk)))
    }

    @Test("an alert appears only when the user has set a threshold and it is crossed")
    func alertOnlyWhenCrossed() {
        var config = MenuBarItemConfig(style: .value)
        config.alertAbove = 80
        let snapshot = SystemSnapshot(cpuPercent: 90)
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .cpu, snapshot: snapshot, config: config, history: [:], physicalMemoryBytes: physical
        )
        #expect(glyph == .text(symbol: MetricSymbol.cpu, value: "90%", alert: true))

        config.alertAbove = nil
        let noAlert = MenuBarGlyphBuilder.glyph(
            for: .cpu, snapshot: snapshot, config: config, history: [:], physicalMemoryBytes: physical
        )
        #expect(noAlert == .text(symbol: MetricSymbol.cpu, value: "90%", alert: false))
    }

    @Test("sample history keeps only the last 60 values")
    func historyCapacity() {
        var history = SampleHistory()
        for value in 0..<100 { history.append(Double(value)) }
        #expect(history.values.count == SampleHistory.capacity)
        #expect(history.values.first == 40)
        #expect(history.values.last == 99)
    }
}
