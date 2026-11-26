import AppKit
import StatusMonitorCore
import SwiftUI

/// The Settings window: every configuration in one place. The popover only shows values and opens this window.
struct SettingsView: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var purge: PurgePermissionViewModel

    enum SettingsSection: String, CaseIterable, Identifiable {
        case menuBarItems
        case general
        case about

        var id: String { rawValue }
        var title: String {
            switch self {
            case .menuBarItems: return "Menu Bar Items"
            case .general: return "General"
            case .about: return "About"
            }
        }
        var symbol: String {
            switch self {
            case .menuBarItems: return "menubar.rectangle"
            case .general: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }

    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.section) {
                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("StatusMonitor")
                        .font(.headline)
                }
                .padding(.vertical, 4)
                ForEach(SettingsSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch navigation.section ?? SettingsSection.menuBarItems {
            case .menuBarItems: menuBarItems
            case .general: general
            case .about: about
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .preferredColorScheme(settings.settings.appearance.colorScheme)
        .tint(Brand.accent)
    }

    // MARK: - Menu Bar Items

    private var menuBarItems: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(navigation.isReordering
                         ? "Drag rows to set the order. Press Done when finished."
                         : "Press Reorder to drag the items into a new order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(navigation.isReordering ? "Done" : "Reorder") {
                        navigation.isReordering.toggle()
                    }
                }
                .padding(12)
                List(selection: $navigation.selected) {
                    // RAM is merged into the CPU item, so it has no row of its own.
                    ForEach(settings.settings.menuBarOrder.filter { $0 != .ram }, id: \.self) { item in
                        itemRow(item).tag(item).moveDisabled(!navigation.isReordering)
                    }
                    .onMove { source, destination in
                        var order = settings.settings.menuBarOrder.filter { $0 != .ram }
                        order.move(fromOffsets: source, toOffset: destination)
                        settings.setMenuBarOrder(order + [.ram])
                    }
                }
            }
            .frame(width: 280)

            Divider()

            if let item = navigation.selected {
                itemDetail(item)
            } else {
                Text("Select an item to configure it.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func itemRow(_ item: MetricItemID) -> some View {
        HStack(spacing: 10) {
            Image(systemName: Self.symbol(for: item))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.name(for: item))
                Text(settings.settings.priority(for: item).label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Show \(Self.name(for: item)) in menu bar", isOn: barBinding(item))
                .labelsHidden()
                .disabled(!isSupported(item))
        }
    }

    private func itemDetail(_ item: MetricItemID) -> some View {
        let config = settings.settings.itemConfig(for: item)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.name(for: item))
                    .font(.title2.weight(.semibold))

                preview(for: item, config: config)
                chartSection(for: item)
                if item == .disk && config.hideWhenIdle {
                    Text("Disk hides while idle. It appears in the bar only when reads or writes exceed the idle level below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Display") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Style", selection: styleBinding(item, config)) {
                            ForEach(MenuBarItemConfig.allowedStyles(for: item), id: \.self) { style in
                                Text(Self.label(for: style)).tag(style)
                            }
                        }
                        Picker("Priority", selection: priorityBinding(item)) {
                            ForEach(MenuBarPriority.allCases, id: \.self) { priority in
                                Text(priority.label).tag(priority)
                            }
                        }
                        Picker("Refresh every", selection: refreshBinding(item, config)) {
                            ForEach(MenuBarRefresh.allCases, id: \.self) { refresh in
                                Text("\(refresh.rawValue) second\(refresh.rawValue == 1 ? "" : "s")").tag(refresh)
                            }
                        }
                        Picker("On click", selection: clickBinding(item, config)) {
                            Text("Show popover").tag(MenuBarClickAction.showPopover)
                            Text("Open Activity Monitor").tag(MenuBarClickAction.openActivityMonitor)
                            Text("Nothing").tag(MenuBarClickAction.nothing)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if item == .network || item == .disk {
                    GroupBox("Idle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Hide while idle", isOn: hideIdleBinding(item, config))
                            HStack {
                                Text("Idle below")
                                TextField("KB/s", value: idleKBBinding(item, config), format: .number)
                                    .frame(width: 80)
                                    .textFieldStyle(.roundedBorder)
                                Text("KB/s").foregroundStyle(.secondary)
                            }
                            .disabled(!config.hideWhenIdle)
                        }
                        .padding(.vertical, 4)
                    }
                }

                GroupBox("Alert") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Alert above a threshold", isOn: alertOnBinding(item, config))
                        HStack {
                            Text("Above")
                            TextField(Self.alertUnit(item), value: alertBinding(item, config), format: .number)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                            Text(Self.alertUnit(item)).foregroundStyle(.secondary)
                        }
                        .disabled(config.alertAbove == nil)
                        Text("Above the threshold the item turns orange, and shows a triangle with bold digits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if item == .cpu {
                    GroupBox("Shows") {
                        Picker("Value", selection: Binding(
                            get: { settings.settings.cpuMode },
                            set: { settings.setCPUMode($0) }
                        )) {
                            Text("CPU %").tag(CPUDisplayMode.percent)
                            Text("RAM GB").tag(CPUDisplayMode.memoryGB)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                    }
                }

                if item == .cpu {
                    GroupBox("Memory Clean") {
                        VStack(alignment: .leading, spacing: 8) {
                Toggle("Auto Clean", isOn: Binding(
                    get: { settings.settings.autoCleanEnabled },
                    set: { settings.setAutoCleanEnabled($0) }
                ))
                Text("Purge when used RAM reaches \(settings.settings.autoCleanThresholdPercent)%")
                Text("RAM turns orange 10 points below this, and red at it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(settings.settings.autoCleanThresholdPercent) },
                        set: { settings.setAutoCleanThresholdPercent(Int($0.rounded())) }
                    ),
                    in: Double(AutoCleanThreshold.minimumPercent)...Double(AutoCleanThreshold.maximumPercent),
                    step: Double(AutoCleanThreshold.stepPercent)
                )
                .disabled(!settings.settings.autoCleanEnabled)
        
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let collector = Self.collector(for: item) {
                    GroupBox("Card") {
                        Toggle("Show card in the popover", isOn: collectorBinding(collector))
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// The item's recent history, drawn the same way as on its card.
    @ViewBuilder
    private func chartSection(for item: MetricItemID) -> some View {
        let h = monitor.histories
        let series: [ChartSeries] = {
            switch item {
            case .cpu: return [ChartSeries(id: "cpu", values: h[.cpu]?.values ?? [], color: Brand.accent)]
            case .gpu: return [ChartSeries(id: "gpu", values: h[.gpu]?.values ?? [], color: Brand.accent)]
            case .network:
                return [
                    ChartSeries(id: "download", values: h[.networkDown]?.values ?? [], color: Brand.accent),
                    ChartSeries(id: "upload", values: h[.networkUp]?.values ?? [], color: Brand.warm, dashed: true),
                ]
            case .disk:
                return [
                    ChartSeries(id: "read", values: h[.diskRead]?.values ?? [], color: Brand.accent),
                    ChartSeries(id: "write", values: h[.diskWrite]?.values ?? [], color: Brand.warm, dashed: true),
                ]
            case .thermal: return [ChartSeries(id: "temperature", values: h[.temperature]?.values ?? [], color: Brand.accent)]
            case .ram, .memoryPressure, .battery: return []
            }
        }()
        if series.contains(where: { !$0.values.isEmpty }) {
            let domain: ClosedRange<Double>? = (item == .cpu || item == .gpu) ? 0...100 : nil
            GroupBox("History") {
                VStack(alignment: .leading, spacing: 6) {
                    HistoryChart(series: series, yDomain: domain)
                    HistoryStats(stats: SeriesStatistics.of(series.first?.values ?? []), format: { Self.format(item, $0) })
                }
                .padding(.vertical, 4)
            }
        }
    }

    static func format(_ item: MetricItemID, _ value: Double) -> String {
        switch item {
        case .network, .disk: return Format.rate(value)
        case .thermal: return Format.celsius(value)
        default: return Format.percent(value)
        }
    }

    /// The live glyph for this item, drawn exactly as the menu bar draws it, so edits show up here first.
    private func preview(for item: MetricItemID, config: MenuBarItemConfig) -> some View {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: item,
            snapshot: monitor.snapshot,
            config: config,
            history: monitor.histories,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
        )
        let image = glyph.map { MenuBarImageRenderer.image(for: $0) } ?? MenuBarImageRenderer.iconOnly(symbol: Self.symbol(for: item))
        return HStack {
            Spacer()
            Image(nsImage: image)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
        .accessibilityLabel("Preview of \(Self.name(for: item)) in the menu bar")
    }

    // MARK: - About

    private var about: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("StatusMonitor")
                .font(.title2.weight(.semibold))
            Text("Version \(version) (\(build))")
                .foregroundStyle(.secondary)
            Text("Menu bar metrics for CPU and RAM, GPU, memory pressure, network, disk, battery and temperature.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - General

    private var general: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { settings.settings.appearance },
                    set: { settings.setAppearance($0) }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Startup") {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.opensAtLogin },
                    set: { settings.setOpensAtLogin($0) }
                ))
                if let error = settings.loginItemError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Purge permission") {
                HStack {
                    Text("Memory Clean runs purge with a one-time approval.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    purgeButton
                }
                purgeStatus
            }

            Section("Battery details") {
                ForEach(BatteryDetail.allCases, id: \.self) { detail in
                    Toggle(Self.batteryDetailName(detail), isOn: Binding(
                        get: { settings.settings.isBatteryDetailShown(detail) },
                        set: { settings.setBatteryDetail(detail, shown: $0) }
                    ))
                }
            }

            Section("Network") {
                Toggle("Include loopback (lo0)", isOn: Binding(
                    get: { settings.settings.includeLoopback },
                    set: { settings.setIncludeLoopback($0) }
                ))
                TextField("Interfaces, e.g. en0, utun3 (blank = all)", text: $settings.interfaceText)
            }
        }
        .formStyle(.grouped)
        .onAppear { purge.refresh() }
    }

    @ViewBuilder
    private var purgeButton: some View {
        switch purge.state {
        case .installed:
            Button("Remove") { purge.uninstall() }
        case .notInstalled, .failed:
            Button("Install…") { purge.install() }
        case .working:
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private var purgeStatus: some View {
        switch purge.state {
        case .installed: Text("Installed.").font(.caption).foregroundStyle(.secondary)
        case .notInstalled: Text("Not installed.").font(.caption).foregroundStyle(.secondary)
        case .working: Text("Waiting for the administrator prompt…").font(.caption).foregroundStyle(.secondary)
        case .failed(let message): Text(message).font(.caption).foregroundStyle(.red)
        }
    }

    // MARK: - Bindings

    /// Show-in-bar for an item. CPU and network use their own switches; the rest use the per-item list.
    /// Whether this Mac can provide the item. Items it cannot provide stay off and show why.
    private func isSupported(_ item: MetricItemID) -> Bool {
        guard let collector = Self.collector(for: item) else { return true }
        return monitor.capabilities.supports(collector)
    }

    private func barBinding(_ item: MetricItemID) -> Binding<Bool> {
        Binding(
            get: { settings.settings.isMenuBarItemVisible(item, capabilities: monitor.capabilities) },
            set: { shown in settings.setItemInMenuBar(item, shown: shown) }
        )
    }

    private func styleBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<MenuBarItemStyle> {
        Binding(
            get: { config.style },
            set: { style in
                var next = config
                next.style = style
                settings.setItemConfig(item, next)
            }
        )
    }

    private func priorityBinding(_ item: MetricItemID) -> Binding<MenuBarPriority> {
        Binding(
            get: { settings.settings.priority(for: item) },
            set: { settings.setMenuBarPriority(item, $0) }
        )
    }

    private func refreshBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<MenuBarRefresh> {
        Binding(
            get: { config.refresh },
            set: { refresh in
                var next = config
                next.refresh = refresh
                settings.setItemConfig(item, next)
            }
        )
    }

    private func clickBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<MenuBarClickAction> {
        Binding(
            get: { config.onClick },
            set: { action in
                var next = config
                next.onClick = action
                settings.setItemConfig(item, next)
            }
        )
    }

    private func hideIdleBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Bool> {
        Binding(
            get: { config.hideWhenIdle },
            set: { value in
                var next = config
                next.hideWhenIdle = value
                settings.setItemConfig(item, next)
            }
        )
    }

    /// The idle threshold is entered in KB/s and stored in bytes per second.
    private func idleKBBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Double> {
        Binding(
            get: { config.idleBelow / 1_000 },
            set: { kb in
                var next = config
                next.idleBelow = max(0, kb) * 1_000
                settings.setItemConfig(item, next)
            }
        )
    }

    private func alertOnBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Bool> {
        Binding(
            get: { config.alertAbove != nil },
            set: { on in
                var next = config
                next.alertAbove = on ? Self.defaultAlert(for: item) : nil
                settings.setItemConfig(item, next)
            }
        )
    }

    private func alertBinding(_ item: MetricItemID, _ config: MenuBarItemConfig) -> Binding<Double> {
        Binding(
            get: { config.alertAbove ?? Self.defaultAlert(for: item) },
            set: { value in
                var next = config
                next.alertAbove = value
                settings.setItemConfig(item, next)
            }
        )
    }

    private func collectorBinding(_ collector: CollectorKind) -> Binding<Bool> {
        Binding(
            get: { settings.settings.collectorOverrides[collector] ?? true },
            set: { settings.setCollectorEnabled(collector, $0) }
        )
    }

    // MARK: - Labels

    static func name(for item: MetricItemID) -> String {
        switch item {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .gpu: return "GPU"
        case .memoryPressure: return "Memory pressure"
        case .network: return "Network"
        case .disk: return "Disk I/O"
        case .battery: return "Battery"
        case .thermal: return "Temperature"
        }
    }

    static func symbol(for item: MetricItemID) -> String {
        switch item {
        case .cpu: return MetricSymbol.cpu
        case .ram: return MetricSymbol.memory
        case .gpu: return MetricSymbol.gpu
        case .memoryPressure: return MetricSymbol.memoryPressure
        case .network: return MetricSymbol.network
        case .disk: return MetricSymbol.disk
        case .battery: return MetricSymbol.battery(percent: 100, charging: false)
        case .thermal: return MetricSymbol.thermal
        }
    }

    static func label(for style: MenuBarItemStyle) -> String {
        switch style {
        case .value: return "Value"
        case .stacked: return "Stacked"
        case .bars: return "Bars"
        case .sparkline: return "Sparkline"
        case .ring: return "Ring"
        case .grouped: return "Grouped with alert"
        case .icon: return "Icon only"
        }
    }

    static func collector(for item: MetricItemID) -> CollectorKind? {
        switch item {
        case .gpu: return .gpu
        case .memoryPressure: return .memoryPressure
        case .disk: return .disk
        case .battery: return .battery
        case .thermal: return .thermal
        case .cpu, .ram, .network: return nil
        }
    }

    static func defaultAlert(for item: MetricItemID) -> Double {
        switch item {
        case .network: return 50_000_000
        case .disk: return 500_000_000
        case .thermal: return 90
        default: return 80
        }
    }

    static func alertUnit(_ item: MetricItemID) -> String {
        switch item {
        case .network, .disk: return "MB/s"
        case .thermal: return "°C"
        default: return "%"
        }
    }

    static func batteryDetailName(_ detail: BatteryDetail) -> String {
        switch detail {
        case .charge: return "Charge row"
        case .powerFlow: return "Charging / discharging watts"
        case .menuBarCharge: return "Battery % in menu bar"
        case .health: return "Health"
        case .cycles: return "Cycle count"
        case .powerState: return "Power state"
        case .lowPowerMode: return "Low Power Mode"
        case .timeRemaining: return "Time remaining"
        }
    }
}

extension MenuBarPriority {
    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

extension MenuBarRefresh: Identifiable {
    public var id: Int { rawValue }
}
