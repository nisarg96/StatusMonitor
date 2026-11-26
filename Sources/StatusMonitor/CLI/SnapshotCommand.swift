import AppKit
import StatusMonitorCore
import SwiftUI

/**
 The developer flag `StatusMonitor --snapshot <folder>`, which renders the real views to PNG files for the README
 screenshots and then returns.

 No status bar item, popover or Settings window is started, nothing is installed, and no clean runs.
 */
@MainActor
enum SnapshotCommand {
    /// Pixels per point. The bitmaps are allocated at this density by hand, so the output ignores the screen.
    static let scale = 2
    /// The width of the popover, in points.
    static let popoverWidth: CGFloat = 380
    /// The largest popover height, in points. A taller popover is cut at this height.
    static let popoverMaxHeight: CGFloat = 600
    /// The size of the Settings window, in points.
    static let settingsSize = NSSize(width: 960, height: 680)
    /// The height of the menu bar strip, in points.
    static let menuBarStripHeight: CGFloat = 28
    /// The refresh cadence while the popover is open, in seconds.
    static let refreshInterval: TimeInterval = MonitorViewModel.openInterval
    /// How long to sample before the capture, in seconds.
    static let captureTime: TimeInterval = 6
    /// Time for SwiftUI to lay out and attach each offscreen window before it is captured, in seconds.
    static let layoutTime: TimeInterval = 1
    private static let suiteName = "StatusMonitor.snapshot"

    /**
     Builds the app's wiring on a throwaway defaults suite.

     The user's settings, daily traffic and remediation log are neither read nor written, so the screenshots show the
     default configuration.

     - Returns: A composition root in snapshot mode.
     - Precondition: The snapshot defaults suite can be created.
     */
    static func makeRoot() -> CompositionRoot {
        discardDefaults()
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("the snapshot defaults suite cannot be created")
        }
        return CompositionRoot(defaults: defaults, snapshot: true)
    }

    /// Removes the snapshot's defaults domain and its plist, so nothing of the snapshot is left in Preferences.
    private static func discardDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        let plist = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: plist)
    }

    /**
     Renders the menu bar strips, the popovers and the Settings panes into PNG files in `folder`.

     The snapshot defaults are removed when the run ends, whether or not it succeeds.

     - Parameter folder: The folder to write the PNG files into. It is created if needed.
     - Parameter root: The composition root from `makeRoot()`.
     - Throws: The error from creating the folder or writing a file, or `CocoaError` when a bitmap cannot be encoded.
     */
    static func run(folder: String, root: CompositionRoot) throws {
        defer { discardDefaults() }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.accessory)

        sampleMonitor(root.monitor)

        let light = menuBarStrip(root.monitor, appearance: .aqua, fill: rgb(0xECECEE))
        try write(light, "menu-bar-light.png", directory)
        let dark = menuBarStrip(root.monitor, appearance: .darkAqua, fill: rgb(0x2B2F36))
        try write(dark, "menu-bar-dark.png", directory)

        try write(capture(popoverWindow(root, appearance: .aqua)), "popover-light.png", directory)
        try write(capture(popoverWindow(root, appearance: .darkAqua)), "popover-dark.png", directory)

        let panes: [(file: String, pane: SettingsPane)] = [
            ("settings-menu-bar-items.png", .menuBarItems),
            ("settings-memory-clean.png", .memoryClean)
        ]
        for entry in panes {
            try write(capture(settingsWindow(root, pane: entry.pane)), entry.file, directory)
        }
    }

    // MARK: - Monitor

    /**
     Waits up to 3 seconds for the capability probe, then refreshes at the popover cadence until the capture time.

     Each refresh is a real sample, so the charts get points. It calls `refresh()` directly and never `start()`, which
     would also drive Auto Clean. The snapshot root has no coordinator, so that path is inert here too.

     - Parameter monitor: The monitor to refresh.
     */
    private static func sampleMonitor(_ monitor: MonitorViewModel) {
        let deadline = Date().addingTimeInterval(3)
        while monitor.capabilities.available.isEmpty, Date() < deadline {
            spin(for: 0.05)
        }
        let start = Date()
        let steps = Int(captureTime / refreshInterval)
        for step in 0...steps {
            spin(until: start.addingTimeInterval(TimeInterval(step) * refreshInterval))
            monitor.refresh()
        }
    }

    /**
     Runs the main run loop until `date`.

     A timer is attached, so the loop sleeps between events instead of spinning. Without a source, `RunLoop.run(until:)`
     returns at once, and a busy loop would count its own CPU in the chart.

     - Parameter date: The time to run the loop until.
     */
    private static func spin(until date: Date) {
        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.run(until: date)
        timer.invalidate()
    }

    /**
     Runs the main run loop for the given number of seconds. See `spin(until:)`.

     - Parameter seconds: The number of seconds to run the loop.
     */
    private static func spin(for seconds: TimeInterval) {
        spin(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Windows and capture

    /**
     Creates an offscreen window that holds the popover content, sized to its content up to the maximum height.

     - Parameter root: The composition root that supplies the view models.
     - Parameter appearance: The appearance the window draws in.
     - Returns: The window, sized to the popover's fitted height.
     */
    private static func popoverWindow(_ root: CompositionRoot, appearance: NSAppearance.Name) -> NSWindow {
        let view = PopoverView(
            settings: root.settings, monitor: root.monitor, only: nil, openSettings: {},
            memoryClean: root.memoryClean, speedTest: root.speedTest
        )
        let hosting = NSHostingView(rootView: view)
        let window = offscreenWindow(hosting, size: NSSize(width: popoverWidth, height: popoverMaxHeight),
                                     appearance: appearance)
        hosting.layoutSubtreeIfNeeded()
        let fitted = hosting.fittingSize.height
        let height = fitted > 1 ? min(fitted, popoverMaxHeight) : popoverMaxHeight
        window.setContentSize(NSSize(width: popoverWidth, height: height))
        return window
    }

    /**
     Creates an offscreen window that holds the Settings view, opened on the given pane.

     - Parameter root: The composition root that supplies the view models.
     - Parameter pane: The Settings pane to select.
     - Returns: The window, sized to `settingsSize`.
     */
    private static func settingsWindow(_ root: CompositionRoot, pane: SettingsPane) -> NSWindow {
        let navigation = SettingsNavigation()
        navigation.select(.pane(pane))
        let view = SettingsView(
            settings: root.settings, monitor: root.monitor, purge: root.purge,
            navigation: navigation, memoryClean: root.memoryClean, speedTest: root.speedTest
        )
        return offscreenWindow(NSHostingView(rootView: view), size: settingsSize, appearance: .aqua)
    }

    /**
     Creates a borderless window that is never ordered front. It exists only so SwiftUI lays out and attaches the view.

     - Parameter content: The view to host as the window's content.
     - Parameter size: The window's content size, in points.
     - Parameter appearance: The appearance the window draws in.
     - Returns: The window.
     */
    private static func offscreenWindow(_ content: NSView, size: NSSize, appearance: NSAppearance.Name) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        window.contentView = content
        return window
    }

    /**
     Draws the window's content view into a bitmap at `scale` pixels per point, then closes the window.

     Layout and attachment happen first, during the wait.

     - Parameter window: The window whose content view is captured.
     - Returns: The bitmap of the content view.
     - Precondition: The window has a content view.
     */
    private static func capture(_ window: NSWindow) -> NSBitmapImageRep {
        guard let view = window.contentView else { preconditionFailure("the snapshot window has no content view") }
        spin(for: layoutTime)
        view.layoutSubtreeIfNeeded()
        let rep = bitmap(points: view.bounds.size)
        view.cacheDisplay(in: view.bounds, to: rep)
        window.close()
        return rep
    }

    // MARK: - Menu bar

    /**
     Draws the default status bar items on a strip of the given fill, as the bar draws them.

     Template images take the label colour of the strip's appearance.

     - Parameter monitor: The monitor that supplies the visible items and their glyphs.
     - Parameter appearance: The appearance the strip draws in.
     - Parameter fill: The strip's background colour.
     - Returns: The bitmap of the strip.
     */
    private static func menuBarStrip(
        _ monitor: MonitorViewModel, appearance: NSAppearance.Name, fill: NSColor
    ) -> NSBitmapImageRep {
        let images = monitor.visibleItems.compactMap { item in
            monitor.itemGlyphs[item].map(MenuBarImageRenderer.image(for:))
        }
        let padding: CGFloat = 10
        let gap: CGFloat = 12
        let contentWidth = images.reduce(0) { $0 + $1.size.width } + gap * CGFloat(max(0, images.count - 1))
        let size = NSSize(width: contentWidth + padding * 2, height: menuBarStripHeight)
        let rep = bitmap(points: size)
        draw(into: rep, appearance: appearance) {
            fill.setFill()
            NSRect(origin: .zero, size: size).fill()
            var originX = padding
            for image in images {
                let drawn = image.isTemplate ? tinted(image, with: .labelColor) : image
                let originY = (size.height - image.size.height) / 2
                drawn.draw(in: NSRect(x: originX, y: originY, width: image.size.width, height: image.size.height))
                originX += image.size.width + gap
            }
        }
        return rep
    }

    /**
     Returns a copy of an image filled with one colour, keeping its alpha.

     - Parameter image: The image to tint.
     - Parameter color: The colour to fill the image's opaque pixels with.
     - Returns: The tinted image.
     */
    private static func tinted(_ image: NSImage, with color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    // MARK: - Bitmaps and files

    /**
     Creates an empty bitmap with `scale` pixels per point.

     `size` stays in points, so drawing coordinates are points.

     - Parameter size: The size of the bitmap, in points.
     - Returns: The bitmap.
     - Precondition: The bitmap can be allocated.
     */
    private static func bitmap(points size: NSSize) -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * CGFloat(scale)).rounded(.up)),
            pixelsHigh: Int((size.height * CGFloat(scale)).rounded(.up)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            preconditionFailure("the snapshot bitmap cannot be allocated")
        }
        rep.size = size
        return rep
    }

    /**
     Runs a drawing closure into a bitmap, under a fixed appearance.

     - Parameter rep: The bitmap to draw into.
     - Parameter appearance: The appearance to draw under.
     - Parameter body: The drawing to run.
     - Precondition: The bitmap has a graphics context.
     */
    private static func draw(into rep: NSBitmapImageRep, appearance: NSAppearance.Name, _ body: () -> Void) {
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            preconditionFailure("the snapshot bitmap has no graphics context")
        }
        let drawingAppearance = NSAppearance(named: appearance) ?? NSAppearance.currentDrawing()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        drawingAppearance.performAsCurrentDrawingAppearance(body)
        NSGraphicsContext.restoreGraphicsState()
    }

    /**
     Encodes a bitmap as PNG, writes it atomically into a folder, and prints the file's path and pixel size.

     - Parameter rep: The bitmap to write.
     - Parameter name: The file name, such as `popover-light.png`.
     - Parameter directory: The folder to write into.
     - Throws: `CocoaError` when the bitmap cannot be encoded, or the error from writing the file.
     */
    private static func write(_ rep: NSBitmapImageRep, _ name: String, _ directory: URL) throws {
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        print("wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh) px)")
    }

    /**
     Creates an opaque sRGB colour from a 24-bit hex value.

     - Parameter hex: The colour as `0xRRGGBB`.
     - Returns: The colour.
     */
    private static func rgb(_ hex: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
