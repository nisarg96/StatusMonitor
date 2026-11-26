import Testing
@testable import StatusMonitorCore

@Suite("Formatting")
struct FormattingTests {
    @Test("percent rounds and clamps to 0...100")
    func percent() {
        #expect(Format.percent(11.6) == "12%")
        #expect(Format.percent(-4) == "0%")
        #expect(Format.percent(140) == "100%")
    }

    @Test("gib uses binary gigabytes with one decimal")
    func gib() {
        #expect(Format.gib(3_221_225_472) == "3.0 GB")
        #expect(Format.gib(3_435_973_837) == "3.2 GB")
    }

    @Test("rate picks the unit by 1024 steps")
    func rateUnits() {
        #expect(Format.rate(0) == "0 B/s")
        #expect(Format.rate(1_021) == "1021 B/s")
        #expect(Format.rate(2_048) == "2.0 KB/s")
        #expect(Format.rate(1_258_291) == "1.2 MB/s")
        #expect(Format.rate(-5) == "0 B/s")
    }

    @Test("duration shows hours and minutes, or minutes alone under an hour")
    func duration() {
        #expect(Format.duration(minutes: 134) == "2h 14m")
        #expect(Format.duration(minutes: 45) == "45m")
    }
}

@Suite("StatusTitleFormatter")
struct StatusTitleFormatterTests {
    private let base = SystemSnapshot(
        cpuPercent: 8, memoryUsedBytes: 3_435_973_837, downBps: 2_202_009, upBps: 419_430
    )

    @Test("CPU and network segments, joined with a middle dot")
    func cpuAndNetwork() {
        // By default the bar shows CPU, RAM, GPU and network. Memory pressure, disk, battery and temperature start
        // hidden.
        let title = StatusTitleFormatter.title(for: base, settings: MetricSettings())
        #expect(title == "CPU 8% · RAM 3.2 GB · ↓ 2.1 MB/s ↑ 409.6 KB/s")
    }

    @Test("memory mode shows used RAM instead of CPU percent")
    func memoryMode() {
        let settings = MetricSettings(cpuMode: .memoryGB)
        #expect(StatusTitleFormatter.title(for: base, settings: settings).hasPrefix("RAM 3.2 GB"))
    }

    @Test("hiding CPU removes its segment")
    func hideCPU() {
        let settings = MetricSettings(showCPU: false)
        #expect(!StatusTitleFormatter.title(for: base, settings: settings).contains("CPU"))
    }

    @Test("hiding network removes the arrows")
    func hideNetwork() {
        let settings = MetricSettings(showNetwork: false)
        #expect(StatusTitleFormatter.title(for: base, settings: settings) == "CPU 8% · RAM 3.2 GB")
    }

    @Test("nothing enabled falls back to a clickable placeholder")
    func nothingEnabled() {
        let settings = MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])
        #expect(StatusTitleFormatter.title(for: SystemSnapshot(), settings: settings) == "SM")
    }

    @Test("GPU, memory pressure, disk, battery, and temperature segments appear when present")
    func optionalSegments() {
        var snapshot = base
        snapshot.gpu = GPUReading(utilizationPercent: 12)
        snapshot.memoryPressure = .normal
        snapshot.disk = DiskRates(readBps: 1_258_291, writeBps: 0)
        snapshot.battery = BatteryReading(
            currentPercent: 84, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        snapshot.thermal = ThermalReading(cpuTemperatureC: 54.4, fans: [])

        // Every item shown, so the full bar is checked.
        let title = StatusTitleFormatter.title(for: snapshot, settings: MetricSettings(hiddenMenuBarItems: []))
        #expect(title == "CPU 8% · RAM 3.2 GB · GPU 12% · Mem Normal · "
            + "↓ 2.1 MB/s ↑ 409.6 KB/s · Disk ↓ 1.2 MB/s ↑ 0 B/s · 🔋 84% · 54 °C")
    }

    @Test("a missing optional value drops its segment with no empty separator")
    func collapsesMissingSegments() {
        var snapshot = base
        snapshot.gpu = nil
        snapshot.battery = BatteryReading(
            currentPercent: 84, healthPercent: nil, cycleCount: nil,
            isCharging: false, isOnACPower: false, minutesRemaining: nil
        )
        snapshot.disk = nil
        snapshot.thermal = nil

        let title = StatusTitleFormatter.title(for: snapshot, settings: MetricSettings(hiddenMenuBarItems: []))
        #expect(title == "CPU 8% · RAM 3.2 GB · ↓ 2.1 MB/s ↑ 409.6 KB/s · 🔋 84%")
        #expect(!title.contains("  "))
        #expect(!title.contains(" ·  "))
        #expect(!title.contains("GPU"))
    }

    @Test("charging shows a bolt instead of the battery icon")
    func chargingIcon() {
        var snapshot = SystemSnapshot()
        snapshot.battery = BatteryReading(
            currentPercent: 40, healthPercent: nil, cycleCount: nil,
            isCharging: true, isOnACPower: true, minutesRemaining: nil
        )
        let title = StatusTitleFormatter.title(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(title == "⚡ 40%")
    }
}

@Suite("ReadoutBuilder and InterfaceAllowListParser")
struct ReadoutAndParserTests {
    @Test("core readout lists only enabled CPU and network rows")
    func coreRows() {
        let snapshot = SystemSnapshot(cpuPercent: 50, memoryUsedBytes: 0, downBps: 0, upBps: 0)
        let rows = ReadoutBuilder.rows(for: snapshot, settings: MetricSettings(showNetwork: false))
        #expect(rows.map(\.label) == ["CPU", "Used RAM"])
        #expect(rows.first?.value == "50%")
        #expect(rows.allSatisfy { $0.collector == nil })
    }

    @Test("rows for an absent collector are not produced")
    func absentCollectorProducesNoRows() {
        let rows = ReadoutBuilder.rows(for: SystemSnapshot(), settings: MetricSettings())
        #expect(!rows.contains { $0.collector != nil })
    }

    @Test("GPU rows include VRAM only when used and total are both known")
    func vramRowNeedsBothValues() {
        var snapshot = SystemSnapshot()
        snapshot.gpu = GPUReading(utilizationPercent: 10, vramUsedBytes: 1_073_741_824, vramTotalBytes: nil)
        let noVRAM = ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(noVRAM.map(\.label) == ["GPU"])

        snapshot.gpu = GPUReading(utilizationPercent: 10, vramUsedBytes: 1_073_741_824, vramTotalBytes: 8_589_934_592)
        let withVRAM = ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(withVRAM.map(\.label) == ["GPU", "VRAM"])
        #expect(withVRAM[1].value == "1.0 GB / 8.0 GB")
    }

    @Test("memory pressure accent maps Normal, Warning, and Critical")
    func pressureAccent() {
        for (level, accent) in [(MemoryPressureLevel.normal, ReadoutAccent.normal),
                                (.warning, .warning), (.critical, .critical)] {
            var snapshot = SystemSnapshot()
            snapshot.memoryPressure = level
            let row = ReadoutBuilder.rows(for: snapshot,
                settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])).first
            #expect(row?.value == level.label)
            #expect(row?.accent == accent)
        }
    }

    @Test("battery rows show health, cycles, and power, and time only when it is known")
    func batteryRows() {
        var snapshot = SystemSnapshot()
        snapshot.battery = BatteryReading(
            currentPercent: 84, healthPercent: 91.4, cycleCount: 212,
            isCharging: false, isOnACPower: false, minutesRemaining: 134
        )
        let rows = ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(rows.map(\.label) == ["Charge", "Health", "Cycles", "Power", "Low Power Mode", "Time left"])
        #expect(rows.first { $0.id == "health" }?.value == "91%")
        #expect(rows.first { $0.id == "time" }?.value == "2h 14m")
    }

    @Test("battery with no time estimate omits the time row entirely")
    func batteryNoTimeEstimate() {
        var snapshot = SystemSnapshot()
        snapshot.battery = BatteryReading(
            currentPercent: 84, healthPercent: nil, cycleCount: nil,
            isCharging: true, isOnACPower: true, minutesRemaining: nil
        )
        let rows = ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(!rows.contains { $0.id == "time" })
        #expect(!rows.contains { $0.id == "health" })
        #expect(rows.first { $0.id == "power" }?.value == "Charging")
    }

    @Test("fans are numbered from 1 and a fanless Mac shows no fan rows")
    func fanRows() {
        var snapshot = SystemSnapshot()
        snapshot.thermal = ThermalReading(cpuTemperatureC: nil, fans: [])
        #expect(ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: [])).isEmpty)

        snapshot.thermal = ThermalReading(cpuTemperatureC: nil,
                                          fans: [FanSpeed(index: 0, rpm: 2100), FanSpeed(index: 1, rpm: 1980)])
        let rows = ReadoutBuilder.rows(for: snapshot,
            settings: MetricSettings(showCPU: false, showNetwork: false, hiddenMenuBarItems: []))
        #expect(rows.map(\.label) == ["Fan 1", "Fan 2"])
        #expect(rows.first?.value == "2100 RPM")
    }

    @Test("parser trims, drops blanks and removes duplicates")
    func parseAllowList() {
        #expect(InterfaceAllowListParser.parse(" en0 , utun3,, ") == ["en0", "utun3"])
        #expect(InterfaceAllowListParser.parse("en0, en0").count == 1)
        #expect(InterfaceAllowListParser.parse("").isEmpty)
    }
}
