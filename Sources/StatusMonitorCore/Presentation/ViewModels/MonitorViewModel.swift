import Combine
import Foundation

/**
 Presentation state for live metrics. Owns the refresh cadence, the capability result, and the status bar title.

 Refresh policy:
 - 2 s while the popover is open (live readout).
 - 5 s while it is closed (status bar only), to reduce wakeups and battery use.
 All collectors share this single timer. None of them gets its own.
 */
public final class MonitorViewModel: ObservableObject {
    /// The refresh interval, in seconds, while the popover is open.
    public static let openInterval: TimeInterval = 2
    /// The refresh interval, in seconds, while the popover is closed.
    public static let closedInterval: TimeInterval = 5

    /// Unsampled until the first refresh, so nothing is drawn as a real value before there is one.
    @Published public private(set) var snapshot = SystemSnapshot(isSampled: false)
    /// The plain-text status bar title. A fallback for `statusSegments`.
    @Published public private(set) var statusTitle = ""
    /// Menu bar items as icon + value pairs. The status bar draws these, so the plain `statusTitle` is only a fallback.
    @Published public private(set) var statusSegments: [TitleSegment] = []
    /// Status bar items that should be visible now, in Settings list order.
    @Published public private(set) var visibleItems: [MetricItemID] = []
    /// Value segment for each visible item that has a value. An item missing here shows its icon alone.
    @Published public private(set) var itemSegments: [MetricItemID: TitleSegment] = [:]
    /// What each visible status bar item should draw. The AppKit adapter draws these.
    @Published public private(set) var itemGlyphs: [MetricItemID: MenuBarGlyph] = [:]
    /**
     Every item the user has switched on and the Mac supports, idle or not, in list order.

     The status bar creates all of these up front, so each keeps a fixed slot even while idle.
     */
    @Published public private(set) var candidateItems: [MetricItemID] = []
    /// Recent samples per series. Published so the cards and their charts redraw as values arrive.
    @Published public private(set) var histories: [HistorySeries: SampleHistory] = [:]
    /**
     The same series as `histories`, with each value's wall-clock time.

     The popover charts use these, so hover tooltips show the real time of a sample, including across a sleep gap.
     */
    @Published public private(set) var timedHistories: [HistorySeries: TimedSampleHistory] = [:]
    /// Network totals for the current day, shown on the network card.
    @Published public private(set) var dailyTraffic: DailyTraffic?
    private let trafficStore: DailyTrafficStore?
    private var popoverOpen = false
    /// Empty until the launch probe finishes, so no optional section appears before its availability is known.
    @Published public private(set) var capabilities = MetricCapabilities()

    private let useCase: SampleSystemMetricsUseCase
    private let scheduler: RefreshScheduling
    private let autoClean: AutoCleanCoordinator?
    private let physicalMemoryBytes: UInt64
    private var currentSettings: MetricSettings
    private var enabledCollectors: Set<CollectorKind> = []
    private var cancellables = Set<AnyCancellable>()

    /**
     Creates the view model and subscribes to settings changes.

     Settings are applied immediately. `$settings` emits its current value on subscribe, so the filter and title are
     set up right away.

     - Parameters:
       - useCase: Samples the system metrics on each refresh.
       - settings: The settings view model. Changes to it are applied as they happen.
       - scheduler: Drives the refresh timer.
       - autoClean: Runs the Auto Clean check on each refresh. Nil disables it.
       - physicalMemoryBytes: Physical RAM, in bytes. Used to compute the RAM percentage.
       - trafficStore: Persists today's network totals. Nil keeps them in memory only.
     */
    public init(
        useCase: SampleSystemMetricsUseCase,
        settings: SettingsViewModel,
        scheduler: RefreshScheduling,
        autoClean: AutoCleanCoordinator? = nil,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        trafficStore: DailyTrafficStore? = nil
    ) {
        self.useCase = useCase
        self.scheduler = scheduler
        self.autoClean = autoClean
        self.trafficStore = trafficStore
        self.dailyTraffic = trafficStore?.load()
        self.physicalMemoryBytes = physicalMemoryBytes
        self.currentSettings = settings.settings

        settings.$settings
            .sink { [weak self] newSettings in
                self?.currentSettings = newSettings
                self?.reconfigure()
            }
            .store(in: &cancellables)
    }

    /// Begins sampling at the closed-popover cadence and takes one reading immediately.
    public func start() {
        scheduler.schedule(every: Self.closedInterval) { [weak self] in self?.refresh() }
        refresh()
    }

    /**
     Records whether the popover is open and switches the refresh cadence to match.

     - Parameters:
       - open: True when the popover is open.
     */
    public func setPopoverOpen(_ open: Bool) {
        popoverOpen = open
        let interval = open ? Self.openInterval : Self.closedInterval
        scheduler.schedule(every: interval) { [weak self] in self?.refresh() }
    }

    /// Stops the refresh timer.
    public func stop() {
        scheduler.cancel()
    }

    /**
     Applies the capabilities found by the launch probe.

     Collectors the Mac lacks stay off for good.

     - Parameters:
       - newCapabilities: The capabilities found by the launch probe.
     */
    public func applyCapabilities(_ newCapabilities: MetricCapabilities) {
        capabilities = newCapabilities
        reconfigure()
    }

    /// Takes one sample and republishes the snapshot and title.
    public func refresh() {
        snapshot = useCase.execute()
        recordHistory()
        recordTraffic()
        publishTitle()
        checkAutoClean()
    }

    /**
     Compares used RAM with the Auto Clean threshold on each refresh.

     Used RAM is computed as a percentage of physical RAM.
     */
    private func checkAutoClean() {
        guard let autoClean, physicalMemoryBytes > 0 else { return }
        let usedPercent = Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100
        autoClean.tick(usedPercent: usedPercent, settings: currentSettings)
    }

    private func publishTitle() {
        statusSegments = StatusTitleFormatter.segments(for: snapshot, settings: currentSettings)
        statusTitle = StatusTitleFormatter.title(for: snapshot, settings: currentSettings)
        publishItems()
    }

    /// The network directions the user has switched on. Empty hides the Network item from the bar.
    private var networkDirections: [NetworkDirection] {
        NetworkDirection.shown(in: currentSettings)
    }

    /// Whether an item is on the bar, before idle hiding. The Network item needs at least one direction switched on.
    private func isOnBar(_ item: MetricItemID) -> Bool {
        currentSettings.isMenuBarItemVisible(item, capabilities: capabilities)
            && (item != .network || !networkDirections.isEmpty)
    }

    /**
     Publishes the per-item state for the status bar.

     Visibility is decided here, and a hidden item keeps its position. Visible items are listed in Settings list order,
     which is the bar order. Priority does not change an item's position.
     */
    private func publishItems() {
        let canonical = MetricItemID.allCases
        let visible = canonical
            .filter { item in
                isOnBar(item) && !MenuBarGlyphBuilder.isIdle(
                    item, snapshot: snapshot, config: currentSettings.itemConfig(for: item),
                    networkDirections: networkDirections
                )
            }
            .sorted { lhs, rhs in
                let order = currentSettings.menuBarOrder
                return (order.firstIndex(of: lhs) ?? canonical.count) < (order.firstIndex(of: rhs) ?? canonical.count)
            }
        visibleItems = visible
        candidateItems = canonical
            .filter { isOnBar($0) }
            .sorted { lhs, rhs in
                let order = currentSettings.menuBarOrder
                return (order.firstIndex(of: lhs) ?? canonical.count) < (order.firstIndex(of: rhs) ?? canonical.count)
            }
        var segments: [MetricItemID: TitleSegment] = [:]
        for item in visible {
            if let segment = MenuBarItemFormatter.segment(for: item, snapshot: snapshot, settings: currentSettings) {
                segments[item] = segment
            }
        }
        itemSegments = segments

        var glyphs: [MetricItemID: MenuBarGlyph] = [:]
        for item in visible {
            if let glyph = MenuBarGlyphBuilder.glyph(
                for: item,
                snapshot: snapshot,
                config: currentSettings.itemConfig(for: item),
                history: histories,
                physicalMemoryBytes: physicalMemoryBytes,
                ramThresholdPercent: currentSettings.autoCleanThresholdPercent,
                cpuMode: currentSettings.cpuMode,
                networkDirections: networkDirections
            ) {
                glyphs[item] = glyph
            }
        }
        itemGlyphs = glyphs
    }

    /**
     Adds the bytes that moved since the last sample to today's total.

     The use case measures the bytes from the clock, so a sleep or wake gap is counted by its real traffic rather than
     by the nominal interval. The per-sample values are already byte totals, so they are added with a window of one
     second.
     */
    private func recordTraffic() {
        let day = DailyTraffic.dayKey(for: Date())
        let updated = DailyTraffic.accumulate(
            into: dailyTraffic, day: day,
            downBytesPerSecond: snapshot.downBytesSinceLastSample,
            upBytesPerSecond: snapshot.upBytesSinceLastSample,
            seconds: 1
        )
        dailyTraffic = updated
        trafficStore?.save(updated)
    }

    /**
     Appends this tick's values to each series that has a reading.

     Missing readings are skipped, not zero-filled. Every value from one tick shares one timestamp, so paired series
     (up and down, read and write) line up.
     */
    private func recordHistory() {
        let tick = Date()
        func record(_ series: HistorySeries, _ value: Double?) {
            guard let value else { return }
            histories[series, default: SampleHistory()].append(value)
            timedHistories[series, default: TimedSampleHistory()].append(value, at: tick)
        }
        record(.cpu, snapshot.cpuPercent)
        if physicalMemoryBytes > 0 {
            record(.ram, Double(snapshot.memoryUsedBytes) / Double(physicalMemoryBytes) * 100)
        }
        record(.gpu, snapshot.gpu?.utilizationPercent)
        record(.networkDown, snapshot.downBps)
        record(.networkUp, snapshot.upBps)
        record(.diskRead, snapshot.disk?.readBps)
        record(.diskWrite, snapshot.disk?.writeBps)
        record(.temperature, snapshot.thermal?.cpuTemperatureC)
    }

    /**
     Pushes the current settings and capabilities into the use case.

     Any collector that just turned off is cleared from the snapshot.
     */
    private func reconfigure() {
        enabledCollectors = currentSettings.enabledCollectors(capabilities: capabilities)
        useCase.updateConfiguration(
            filter: InterfaceFilter.from(currentSettings),
            enabled: enabledCollectors
        )
        snapshot = snapshot.retaining(enabledCollectors)
        publishTitle()
    }
}
