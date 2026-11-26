import Combine
import Foundation

/// Presentation state for live metrics. Owns the refresh cadence, the capability result, and the status bar title.
///
/// Refresh policy:
/// - 2 s while the popover is open (live readout).
/// - 5 s while it is closed (status bar only), to reduce wakeups and battery use.
/// All collectors share this single timer. None of them gets its own.
public final class MonitorViewModel: ObservableObject {
    public static let openInterval: TimeInterval = 2
    public static let closedInterval: TimeInterval = 5

    /// Unsampled until the first refresh, so nothing is drawn as a real value before there is one.
    @Published public private(set) var snapshot = SystemSnapshot(isSampled: false)
    @Published public private(set) var statusTitle = ""
    /// Menu bar items as icon + value pairs. The status bar draws these, so the plain `statusTitle` is only a fallback.
    @Published public private(set) var statusSegments: [TitleSegment] = []
    /// Status bar items that should be visible now, highest priority first.
    @Published public private(set) var visibleItems: [MetricItemID] = []
    /// Value segment for each visible item that has a value. An item missing here shows its icon alone.
    @Published public private(set) var itemSegments: [MetricItemID: TitleSegment] = [:]
    /// What each visible status bar item should draw. The AppKit adapter draws these.
    @Published public private(set) var itemGlyphs: [MetricItemID: MenuBarGlyph] = [:]
    /// Every item the user has switched on and the Mac supports, idle or not, in list order.
    /// The status bar creates all of these up front, so each keeps a fixed slot even while idle.
    @Published public private(set) var candidateItems: [MetricItemID] = []
    /// Recent samples per series. Published so the cards and their charts redraw as values arrive.
    @Published public private(set) var histories: [HistorySeries: SampleHistory] = [:]
    /// The same series as `histories`, with each value's wall-clock time. The popover charts use these, so hover
    /// tooltips show the real time of a sample, including across a sleep gap.
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

        // $settings emits its current value on subscribe, so the filter and title are set up immediately.
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

    public func setPopoverOpen(_ open: Bool) {
        popoverOpen = open
        let interval = open ? Self.openInterval : Self.closedInterval
        scheduler.schedule(every: interval) { [weak self] in self?.refresh() }
    }

    public func stop() {
        scheduler.cancel()
    }

    /// Called once the launch probe has finished. Collectors the Mac lacks stay off for good.
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

    /// Used RAM as a percentage of physical RAM, compared with the Auto Clean threshold on each refresh.
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

    /// Per-item state for the status bar. Visibility is decided here; a hidden item keeps its position.
    /// Visible items are listed highest priority first, so their creation order matches importance.
    private func publishItems() {
        let canonical = MetricItemID.allCases
        let visible = canonical
            .filter { item in
                currentSettings.isMenuBarItemVisible(item, capabilities: capabilities)
                    && !MenuBarGlyphBuilder.isIdle(
                        item, snapshot: snapshot, config: currentSettings.itemConfig(for: item))
            }
            .sorted { lhs, rhs in
                // The Settings list order is the bar order. Priority decides what hides first, not where items sit.
                let order = currentSettings.menuBarOrder
                return (order.firstIndex(of: lhs) ?? canonical.count) < (order.firstIndex(of: rhs) ?? canonical.count)
            }
        visibleItems = visible
        candidateItems = canonical
            .filter { currentSettings.isMenuBarItemVisible($0, capabilities: capabilities) }
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
                cpuMode: currentSettings.cpuMode
            ) {
                glyphs[item] = glyph
            }
        }
        itemGlyphs = glyphs
    }

    /// Adds the bytes that moved since the last sample to today's total. The use case measures them from the
    /// clock, so a sleep or wake gap is counted by its real traffic rather than by the nominal interval.
    private func recordTraffic() {
        let day = DailyTraffic.dayKey(for: Date())
        // The per-sample values are already byte totals, so a one-second window adds them unchanged.
        let updated = DailyTraffic.accumulate(
            into: dailyTraffic, day: day,
            downBytesPerSecond: snapshot.downBytesSinceLastSample,
            upBytesPerSecond: snapshot.upBytesSinceLastSample,
            seconds: 1
        )
        dailyTraffic = updated
        trafficStore?.save(updated)
    }

    /// Appends this tick's values to each series that has a reading. Missing readings are skipped, not zero-filled.
    /// Every value from one tick shares one timestamp, so paired series (up and down, read and write) line up.
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

    /// Pushes the current settings and capabilities into the use case, and clears any collector that just turned off.
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
