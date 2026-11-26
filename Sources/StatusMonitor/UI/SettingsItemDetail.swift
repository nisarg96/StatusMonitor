import StatusMonitorCore
import SwiftUI

/// The detail pane for one menu bar item: its light and dark previews, shows, style, options and history.
struct SettingsItemDetail: View {
    /// The menu bar item being configured.
    let item: MetricItemID
    /// The settings view model that the controls edit.
    @ObservedObject var settings: SettingsViewModel
    /// The monitor, which supplies the live glyph and the history.
    @ObservedObject var monitor: MonitorViewModel

    private var config: MenuBarItemConfig { settings.settings.itemConfig(for: item) }
    private var bindings: SettingsItemBindings { SettingsItemBindings(settings: settings, monitor: monitor) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(SettingsItemPresentation.name(for: item))
                    .font(.system(size: 16, weight: .semibold))
                preview
                if item == .cpu {
                    SettingsGroup(title: "Shows") {
                        Picker("Value", selection: bindings.cpuMode()) {
                            Text("CPU %").tag(CPUDisplayMode.percent)
                            Text("RAM GB").tag(CPUDisplayMode.memoryGB)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                if item == .network {
                    SettingsGroup(title: "Shows") {
                        Toggle("Upload", isOn: bindings.networkDirection(.upload))
                        Toggle("Download", isOn: bindings.networkDirection(.download))
                    }
                }
                SettingsGroup(title: "Style") {
                    SettingsStyleChips(item: item, selection: config.style) { style in
                        bindings.style(item, config).wrappedValue = style
                    }
                }
                SettingsItemOptions(item: item, config: config, bindings: bindings)
                if let collector = SettingsItemPresentation.collector(for: item) {
                    SettingsGroup(title: "Card") {
                        Toggle("Show card in the popover", isOn: bindings.collectorOn(collector))
                    }
                }
                SettingsItemHistory(item: item, monitor: monitor)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// The live glyph, drawn exactly as the menu bar draws it, once on a light bar and once on a dark bar.
    private var preview: some View {
        let glyph = MenuBarGlyphBuilder.glyph(
            for: item,
            snapshot: monitor.snapshot,
            config: config,
            history: monitor.histories,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            networkDirections: NetworkDirection.shown(in: settings.settings)
        )
        let image = glyph.map { MenuBarImageRenderer.image(for: $0) }
            ?? MenuBarImageRenderer.iconOnly(symbol: SettingsSymbols.symbol(for: item))
        return HStack(spacing: 10) {
            SettingsPreviewTile(image: image, dark: false)
            SettingsPreviewTile(image: image, dark: true)
        }
        .accessibilityLabel("Preview of \(SettingsItemPresentation.name(for: item)) in the menu bar")
    }
}
