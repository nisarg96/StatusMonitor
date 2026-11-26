import AppKit
import Combine
import StatusMonitorCore
import SwiftUI

/**
 The AppKit view adapter: one `NSStatusItem` per metric, and a popover per item. It holds no business logic.

 Items are created the first time they are visible and then kept. Hiding an item sets `isVisible = false`, which keeps
 its position in the menu bar. A removed item could lose that position.

 Clicking an item opens a popover with just that item's card. The anchor item, shown only when every metric is hidden,
 opens the full popover. Only one popover is open at a time.
 */
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private static let fullKey = "all"

    private var items: [MetricItemID: NSStatusItem] = [:]
    /// Shown only when no metric item is visible, so the app is never unreachable.
    private var anchor: NSStatusItem?
    /// One popover per item, plus the full one, created on first use.
    private var popovers: [String: NSPopover] = [:]
    private let settings: SettingsViewModel
    private let monitor: MonitorViewModel
    private let purge: PurgePermissionViewModel
    private let memoryClean: MemoryCleanViewModel
    private let speedTest: SpeedTestViewModel
    private let settingsWindow: SettingsWindowController
    private var cancellables = Set<AnyCancellable>()

    /**
     Creates the controller and subscribes it to the monitor's visible items and glyphs.

     - Parameter settings: The settings view model.
     - Parameter monitor: The monitor whose visible items and glyphs are drawn.
     - Parameter purge: The purge approval state, passed to the Settings window.
     - Parameter memoryClean: The clean view model, passed to the popovers and the Settings window.
     - Parameter speedTest: The speed test view model, passed to the popovers and the Settings window.
     */
    init(
        settings: SettingsViewModel,
        monitor: MonitorViewModel,
        purge: PurgePermissionViewModel,
        memoryClean: MemoryCleanViewModel,
        speedTest: SpeedTestViewModel
    ) {
        self.settings = settings
        self.monitor = monitor
        self.purge = purge
        self.memoryClean = memoryClean
        self.speedTest = speedTest
        self.settingsWindow = SettingsWindowController(
            settings: settings, monitor: monitor, purge: purge, memoryClean: memoryClean, speedTest: speedTest
        )
        super.init()

        Publishers.CombineLatest(monitor.$visibleItems, monitor.$itemGlyphs)
            .receive(on: RunLoop.main)
            .sink { [weak self] visible, glyphs in self?.sync(visible: visible, glyphs: glyphs) }
            .store(in: &cancellables)
    }

    /**
     Brings the bar in line with the view model: creates new items, shows or hides the rest, and draws each item.

     New items are created in list order. macOS places each new item to the left of the others, and it keeps its own
     record of every item's position, which the app cannot reliably change. Command-drag sets the order.

     - Parameter visible: The items that should be shown, in list order.
     - Parameter glyphs: The glyph to draw for each item that has one.
     */
    private func sync(visible: [MetricItemID], glyphs: [MetricItemID: MenuBarGlyph]) {
        for item in visible where items[item] == nil {
            items[item] = makeItem(for: item)
        }
        for (item, statusItem) in items {
            let shouldShow = visible.contains(item)
            statusItem.isVisible = shouldShow
            if shouldShow {
                draw(item: item, glyph: glyphs[item], on: statusItem)
            }
        }

        if visible.isEmpty {
            if anchor == nil {
                let anchorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                anchorItem.button?.title = "SM"
                anchorItem.button?.target = self
                anchorItem.button?.action = #selector(togglePopover(_:))
                anchor = anchorItem
            }
            anchor?.isVisible = true
        } else {
            anchor?.isVisible = false
        }
    }

    /**
     Creates the status item for a metric.

     The autosave name keeps the item's position in the menu bar, and the user's Command-drag order, across launches.
     The identifier tells the click handler which item was clicked.

     - Parameter item: The metric the status item represents.
     - Returns: The new status item.
     */
    private func makeItem(for item: MetricItemID) -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "StatusMonitor.item.\(item.rawValue)"
        if let button = statusItem.button {
            button.identifier = NSUserInterfaceItemIdentifier(item.rawValue)
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        return statusItem
    }

    /**
     Draws an item from its glyph. An item with no glyph yet shows its icon alone, at its usual width.

     Colours resolve against the bar's own appearance, so the light and dark alert pairs match the menu bar.

     - Parameter item: The metric being drawn.
     - Parameter glyph: The glyph to draw, or nil when there is none yet.
     - Parameter statusItem: The status item to draw on.
     */
    private func draw(item: MetricItemID, glyph: MenuBarGlyph?, on statusItem: NSStatusItem) {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            if let glyph {
                button.image = MenuBarImageRenderer.image(for: glyph)
            } else {
                button.image = MenuBarImageRenderer.iconOnly(symbol: Self.symbol(for: item))
            }
        }
        button.imagePosition = .imageOnly
    }

    /**
     Returns the icon used when an item has no value yet.

     - Parameter item: The metric.
     - Returns: The SF Symbol name.
     */
    private static func symbol(for item: MetricItemID) -> String {
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

    /**
     Returns the popover for an item, or the full one, built on first use and then reused.

     The popover takes its size from the SwiftUI content, so it grows and shrinks with the cards.

     - Parameter key: The metric's raw value, or the full popover's key.
     - Returns: The popover.
     */
    private func popover(for key: String) -> NSPopover {
        if let existing = popovers[key] { return existing }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let only = MetricItemID(rawValue: key)
        let hosting = NSHostingController(
            rootView: PopoverView(
                settings: settings, monitor: monitor, only: only,
                openSettings: { [weak self] in self?.settingsWindow.show() },
                memoryClean: memoryClean,
                speedTest: speedTest
            )
        )
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popovers[key] = popover
        return popover
    }

    /**
     Opens the popover for the item that was clicked, anchored to that item. Clicking it again closes it.

     The item's "On click" setting decides what happens. The anchor has no item, so it always opens the popover.
     Only one popover is open at a time, so any other open popover closes first.

     - Parameter sender: The status bar button that was clicked.
     */
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = sender as? NSStatusBarButton else { return }
        if let key = button.identifier?.rawValue, let item = MetricItemID(rawValue: key) {
            switch settings.settings.itemConfig(for: item).onClick {
            case .showPopover:
                break
            case .openActivityMonitor:
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                return
            case .nothing:
                return
            }
        }
        let key = button.identifier?.rawValue ?? Self.fullKey
        let target = popover(for: key)

        if target.isShown {
            target.performClose(nil)
            return
        }
        for other in popovers.values where other.isShown {
            other.performClose(nil)
        }
        target.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    /**
     Tells the monitor whether any popover is open.

     The monitor samples faster while a popover is open, so the card's chart is live.
     */
    private func refreshOpenState() {
        monitor.setPopoverOpen(popovers.values.contains { $0.isShown })
    }

    /**
     Refreshes the monitor's open state when a popover has shown.

     - Parameter notification: The popover notification. Unused.
     */
    func popoverDidShow(_ notification: Notification) {
        refreshOpenState()
    }

    /**
     Refreshes the monitor's open state when a popover has closed.

     - Parameter notification: The popover notification. Unused.
     */
    func popoverDidClose(_ notification: Notification) {
        refreshOpenState()
    }
}
