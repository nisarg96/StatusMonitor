import Foundation
import Testing
@testable import StatusMonitorCore

@Suite("NetworkDirection rule")
struct NetworkDirectionRuleTests {
    @Test("both switches on show download then upload")
    func bothOn() {
        #expect(NetworkDirection.shown(showDownload: true, showUpload: true) == [.download, .upload])
    }

    @Test("upload only shows upload")
    func uploadOnly() {
        #expect(NetworkDirection.shown(showDownload: false, showUpload: true) == [.upload])
    }

    @Test("download only shows download")
    func downloadOnly() {
        #expect(NetworkDirection.shown(showDownload: true, showUpload: false) == [.download])
    }

    @Test("both switches off show no direction, so the Network item is hidden")
    func bothOff() {
        #expect(NetworkDirection.shown(showDownload: false, showUpload: false).isEmpty)
    }
}

@Suite("Network direction in the menu bar and popover")
struct NetworkDirectionOutputTests {
    private let mib: Double = 1024 * 1024
    private var sample: SystemSnapshot { SystemSnapshot(downBps: mib, upBps: 2 * mib) }

    @Test("upload only: the text value shows the up arrow and the upload rate")
    func uploadOnlyText() {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: MenuBarItemConfig(style: .value),
            history: [:], physicalMemoryBytes: 0, networkDirections: [.upload]
        )
        #expect(glyph == .text(symbol: MetricSymbol.network, value: "↑ \(Format.rate(2 * mib))", alert: false))
    }

    @Test("download only: stacked falls back to one line with the down arrow")
    func downloadOnlyStacked() {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: MenuBarItemConfig(style: .stacked),
            history: [:], physicalMemoryBytes: 0, networkDirections: [.download]
        )
        #expect(glyph == .text(symbol: MetricSymbol.network, value: "↓ \(Format.rate(mib))", alert: false))
    }

    @Test("both directions on: stacked keeps the up and down lines")
    func bothOnStacked() {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: MenuBarItemConfig(style: .stacked),
            history: [:], physicalMemoryBytes: 0, networkDirections: [.download, .upload]
        )
        #expect(glyph == .stacked(
            symbol: MetricSymbol.network, top: "↑ \(Format.rate(2 * mib))", bottom: "↓ \(Format.rate(mib))",
            alert: false
        ))
    }

    @Test("upload only: the sparkline uses the upload history")
    func uploadOnlySparkline() {
        var upHistory = SampleHistory()
        upHistory.append(1)
        upHistory.append(2)
        var downHistory = SampleHistory()
        downHistory.append(8)
        downHistory.append(4)
        let glyph = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: MenuBarItemConfig(style: .sparkline),
            history: [.networkUp: upHistory, .networkDown: downHistory],
            physicalMemoryBytes: 0, networkDirections: [.upload]
        )
        #expect(glyph == .sparkline(
            symbol: MetricSymbol.network, levels: [0.5, 1], value: "↑ \(Format.rate(2 * mib))", alert: false
        ))
    }

    @Test("the alert looks only at the enabled directions")
    func alertUsesEnabledDirectionsOnly() {
        let config = MenuBarItemConfig(style: .value, alertAbove: 1.5 * mib)
        let downOnly = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: config,
            history: [:], physicalMemoryBytes: 0, networkDirections: [.download]
        )
        let uploadOnly = MenuBarGlyphBuilder.glyph(
            for: .network, snapshot: sample, config: config,
            history: [:], physicalMemoryBytes: 0, networkDirections: [.upload]
        )
        #expect(downOnly == .text(symbol: MetricSymbol.network, value: "↓ \(Format.rate(mib))", alert: false))
        #expect(uploadOnly == .text(symbol: MetricSymbol.network, value: "↑ \(Format.rate(2 * mib))", alert: true))
    }

    @Test("upload only leaves only the upload row in the readout")
    func readoutUploadOnly() {
        let rows = ReadoutBuilder.rows(for: sample, settings: MetricSettings(showDownload: false))
        let ids = rows.map(\.id)
        #expect(ids.contains("up"))
        #expect(!ids.contains("down"))
    }

    @Test("the tooltip lists only the enabled directions")
    func tooltipOneDirection() {
        #expect(ChartTooltipText.network(upBps: 2 * mib, downBps: mib, directions: [.upload])
            == ["↑ \(Format.rate(2 * mib))"])
        #expect(ChartTooltipText.network(upBps: 2 * mib, downBps: mib, directions: [.download, .upload])
            == ["↑ \(Format.rate(2 * mib))", "↓ \(Format.rate(mib))"])
    }
}

@Suite("SettingsViewModel network direction setters")
struct NetworkDirectionSetterTests {
    @Test("the upload and download switches persist each change")
    func settersPersist() {
        let repo = InMemorySettingsRepository()
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.setShowUpload(false)
        #expect(repo.stored.showUpload == false)
        #expect(repo.stored.showDownload == true)
        viewModel.setShowDownload(false)
        #expect(repo.stored.showDownload == false)
        #expect(repo.saveCount == 2)
    }
}

@Suite("Network item in the menu bar with both directions off")
struct NetworkItemBothDirectionsOffTests {
    @Test("the Network item leaves the bar and the overflow candidates, and the card stays for its header switch")
    func hiddenWhenBothOff() {
        let fakes = FakeSources()
        let repo = InMemorySettingsRepository()
        let settings = SettingsViewModel(repository: repo)
        let monitor = MonitorViewModel(
            useCase: SampleSystemMetricsUseCase(sources: fakes.sources),
            settings: settings,
            scheduler: FakeRefreshScheduler()
        )
        monitor.applyCapabilities(MetricCapabilities(available: Set(CollectorKind.allCases)))
        monitor.refresh()
        #expect(monitor.visibleItems.contains(.network))

        settings.setShowUpload(false)
        settings.setShowDownload(false)
        monitor.refresh()
        #expect(!monitor.visibleItems.contains(.network))
        #expect(!monitor.candidateItems.contains(.network))
        #expect(repo.stored.showNetwork)
    }
}
