import Foundation
import Testing
@testable import StatusMonitorCore

/// Characterization of MenuBarGlyphBuilder: pins the glyph each item and state produces today, so a refactor of the
/// builder cannot change what the menu bar shows.
@Suite("Menu bar glyph characterization: CPU, RAM, GPU, network, disk")
struct MenuBarGlyphCharacterizationTests {
    private let gib: UInt64 = 1_073_741_824

    // MARK: - CPU

    @Test("CPU value style: symbol and percent, alert flag follows alertAbove")
    func cpuValue() {
        let snapshot = SystemSnapshot(cpuPercent: 42.4)
        #expect(glyphOf(.cpu, snapshot) == .text(symbol: "cpu", value: "42%", alert: false))
        #expect(glyphOf(.cpu, snapshot, alertAbove: 40) == .text(symbol: "cpu", value: "42%", alert: true))
        #expect(glyphOf(.cpu, snapshot, alertAbove: 50) == .text(symbol: "cpu", value: "42%", alert: false))
    }

    @Test("CPU bars, sparkline and ring styles")
    func cpuStyles() {
        let snapshot = SystemSnapshot(cpuPercent: 42.4)
        let samples = historyOf(.cpu, [10, 50, 100])
        #expect(glyphOf(.cpu, snapshot, style: .bars, history: samples)
            == .bars(symbol: "cpu", levels: [0.1, 0.5, 1.0], alert: false))
        #expect(glyphOf(.cpu, snapshot, style: .sparkline, history: samples)
            == .sparkline(symbol: "cpu", levels: [0.1, 0.5, 1.0], value: "42%", alert: false))
        #expect(glyphOf(.cpu, snapshot, style: .ring, alertAbove: 40)
            == .ring(symbol: "cpu", fraction: 42.4 / 100, value: "42%", alert: true))
    }

    @Test("CPU bars and sparkline with no history have no levels")
    func cpuEmptyHistory() {
        let snapshot = SystemSnapshot(cpuPercent: 5)
        #expect(glyphOf(.cpu, snapshot, style: .bars) == .bars(symbol: "cpu", levels: [], alert: false))
        #expect(glyphOf(.cpu, snapshot, style: .sparkline)
            == .sparkline(symbol: "cpu", levels: [], value: "5%", alert: false))
    }

    @Test("CPU with icon or grouped style falls back to the value text")
    func cpuFallback() {
        let snapshot = SystemSnapshot(cpuPercent: 7)
        #expect(glyphOf(.cpu, snapshot, style: .icon) == .text(symbol: "cpu", value: "7%", alert: false))
        #expect(glyphOf(.cpu, snapshot, style: .grouped) == .text(symbol: "cpu", value: "7%", alert: false))
    }

    @Test("CPU in RAM mode shows used GB and takes the RAM accent: normal, warning, critical")
    func cpuMemoryMode() {
        let normal = SystemSnapshot(memoryUsedBytes: 4 * gib)
        let warning = SystemSnapshot(memoryUsedBytes: 7 * gib)
        let critical = SystemSnapshot(memoryUsedBytes: 8 * gib)
        #expect(glyphOf(.cpu, normal, cpuMode: .memoryGB)
            == .level(symbol: "cpu", value: "4.0 GB", accent: .normal))
        #expect(glyphOf(.cpu, warning, cpuMode: .memoryGB)
            == .level(symbol: "cpu", value: "7.0 GB", accent: .warning))
        #expect(glyphOf(.cpu, critical, cpuMode: .memoryGB)
            == .level(symbol: "cpu", value: "8.0 GB", accent: .critical))
    }

    @Test("CPU in RAM mode with no physical memory reading has no glyph")
    func cpuMemoryModeNoPhysical() {
        #expect(glyphOf(.cpu, SystemSnapshot(memoryUsedBytes: gib), physicalBytes: 0, cpuMode: .memoryGB) == nil)
    }

    // MARK: - RAM

    @Test("RAM value style uses the level accent: normal, warning band, critical at the threshold")
    func ramValueAccents() {
        #expect(glyphOf(.ram, SystemSnapshot(memoryUsedBytes: 4 * gib))
            == .level(symbol: "memorychip", value: "4.0 GB", accent: .normal))
        #expect(glyphOf(.ram, SystemSnapshot(memoryUsedBytes: 7 * gib))
            == .level(symbol: "memorychip", value: "7.0 GB", accent: .warning))
        #expect(glyphOf(.ram, SystemSnapshot(memoryUsedBytes: 8 * gib))
            == .level(symbol: "memorychip", value: "8.0 GB", accent: .critical))
    }

    @Test("RAM follows a custom threshold")
    func ramCustomThreshold() {
        // 75% used against an 80% threshold is inside the 10-point warning band (75 >= 80 - 10).
        #expect(glyphOf(.ram, SystemSnapshot(memoryUsedBytes: 6 * gib), threshold: 80)
            == .level(symbol: "memorychip", value: "6.0 GB", accent: .warning))
    }

    @Test("RAM ring, sparkline and alert")
    func ramStyles() {
        let snapshot = SystemSnapshot(memoryUsedBytes: 4 * gib)
        #expect(glyphOf(.ram, snapshot, style: .ring)
            == .ring(symbol: "memorychip", fraction: 0.5, value: "50%", alert: false))
        #expect(glyphOf(.ram, snapshot, style: .ring, alertAbove: 40)
            == .ring(symbol: "memorychip", fraction: 0.5, value: "50%", alert: true))
        #expect(glyphOf(.ram, snapshot, style: .sparkline, history: historyOf(.ram, [40, 50]))
            == .sparkline(symbol: "memorychip", levels: [0.4, 0.5], value: "4.0 GB", alert: false))
    }

    @Test("RAM with no physical memory reading has no glyph")
    func ramNoPhysical() {
        #expect(glyphOf(.ram, SystemSnapshot(memoryUsedBytes: gib), physicalBytes: 0) == nil)
    }

    // MARK: - GPU

    @Test("GPU with no reading has no glyph")
    func gpuNoReading() {
        #expect(glyphOf(.gpu) == nil)
    }

    @Test("GPU value, ring and sparkline styles")
    func gpuStyles() {
        let snapshot = SystemSnapshot(gpu: GPUReading(utilizationPercent: 33.3))
        #expect(glyphOf(.gpu, snapshot) == .label(title: "GPU", value: "33%", alert: false))
        #expect(glyphOf(.gpu, snapshot, style: .ring)
            == .ring(symbol: "display", fraction: 33.3 / 100, value: "33%", alert: false))
        #expect(glyphOf(.gpu, snapshot, style: .sparkline, history: historyOf(.gpu, [0, 100]))
            == .sparkline(symbol: "display", levels: [0, 1], value: "33%", alert: false))
    }

    @Test("GPU label alerts when alertAbove is crossed, and keeps its text label")
    func gpuLabelAlert() {
        let snapshot = SystemSnapshot(gpu: GPUReading(utilizationPercent: 90))
        #expect(glyphOf(.gpu, snapshot, alertAbove: 80)
            == .label(title: "GPU", value: "90%", alert: true))
    }

    // MARK: - Network

    @Test("network stacked shows upload above download, also for grouped")
    func networkStacked() {
        let snapshot = SystemSnapshot(downBps: 340_000, upBps: 1_200_000)
        let expected = MenuBarGlyph.stacked(
            symbol: "network", top: "↑ \(Format.rate(1_200_000))", bottom: "↓ \(Format.rate(340_000))", alert: false
        )
        #expect(glyphOf(.network, snapshot) == expected)
        #expect(glyphOf(.network, snapshot, style: .grouped) == expected)
    }

    @Test("network alert is set by the larger of the two directions")
    func networkAlert() {
        let snapshot = SystemSnapshot(downBps: 340_000, upBps: 1_200_000)
        #expect(glyphOf(.network, snapshot, alertAbove: 1_000_000)
            == .stacked(symbol: "network", top: "↑ \(Format.rate(1_200_000))",
                        bottom: "↓ \(Format.rate(340_000))", alert: true))
    }

    @Test("network sparkline scales to its own peak and shows download")
    func networkSparkline() {
        let snapshot = SystemSnapshot(downBps: 340_000, upBps: 1_200_000)
        #expect(glyphOf(.network, snapshot, style: .sparkline, history: historyOf(.networkDown, [1, 2, 4]))
            == .sparkline(symbol: "network", levels: [0.25, 0.5, 1.0],
                          value: "↓ \(Format.rate(340_000))", alert: false))
    }

    @Test("network sparkline with an all-zero history draws zeros, not a divide by zero")
    func networkSparklineZeroPeak() {
        #expect(glyphOf(.network, SystemSnapshot(), style: .sparkline, history: historyOf(.networkDown, [0, 0]))
            == .sparkline(symbol: "network", levels: [0, 0], value: "↓ \(Format.rate(0))", alert: false))
    }

    @Test("network value style shows download only")
    func networkValue() {
        let snapshot = SystemSnapshot(downBps: 340_000, upBps: 1_200_000)
        #expect(glyphOf(.network, snapshot, style: .value)
            == .text(symbol: "network", value: "↓ \(Format.rate(340_000))", alert: false))
    }

    // MARK: - Disk

    @Test("disk with no reading has no glyph")
    func diskNoReading() {
        #expect(glyphOf(.disk) == nil)
    }

    @Test("disk stacked shows write above read")
    func diskStacked() {
        let snapshot = SystemSnapshot(disk: DiskRates(readBps: 2_000_000, writeBps: 500_000))
        #expect(glyphOf(.disk, snapshot)
            == .stacked(symbol: "internaldrive", top: "↑ \(Format.rate(500_000))",
                        bottom: "↓ \(Format.rate(2_000_000))", alert: false))
    }

    @Test("disk sparkline and value styles use read")
    func diskSparklineAndValue() {
        let snapshot = SystemSnapshot(disk: DiskRates(readBps: 2_000_000, writeBps: 500_000))
        #expect(glyphOf(.disk, snapshot, style: .sparkline, history: historyOf(.diskRead, [1, 3]))
            == .sparkline(symbol: "internaldrive", levels: [1.0 / 3.0, 1.0], value: "↓ \(Format.rate(2_000_000))",
                          alert: false))
        #expect(glyphOf(.disk, snapshot, style: .value)
            == .text(symbol: "internaldrive", value: "↓ \(Format.rate(2_000_000))", alert: false))
    }

    @Test("disk alert uses the larger direction")
    func diskAlert() {
        let snapshot = SystemSnapshot(disk: DiskRates(readBps: 2_000_000, writeBps: 500_000))
        #expect(glyphOf(.disk, snapshot, style: .value, alertAbove: 1_000_000)
            == .text(symbol: "internaldrive", value: "↓ \(Format.rate(2_000_000))", alert: true))
    }
}
