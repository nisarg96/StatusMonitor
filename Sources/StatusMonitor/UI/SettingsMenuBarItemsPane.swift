import StatusMonitorCore
import SwiftUI

/// The Menu bar items page: a reorderable list on the left and the selected item's detail on the right.
struct SettingsMenuBarItemsPane: View {
    /// The settings view model that the list and detail edit.
    @ObservedObject var settings: SettingsViewModel
    /// The monitor, which supplies the capabilities and the live readings.
    @ObservedObject var monitor: MonitorViewModel
    /// The selected pane and menu bar item.
    @ObservedObject var navigation: SettingsNavigation
    /// The speed test shown on the Network item's detail. Nil hides its controls.
    var speedTest: SpeedTestViewModel?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                itemList
                Text("Priority is saved for when overflow hiding is added. "
                    + "Right now every item you turn on is shown.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
            .frame(width: 330)
            Divider()
            detail
        }
    }

    private var itemList: some View {
        let bindings = SettingsItemBindings(settings: settings, monitor: monitor)
        return List(selection: $navigation.selected) {
            ForEach(SettingsItemPresentation.listedItems(order: settings.settings.menuBarOrder), id: \.self) { item in
                SettingsItemRow(item: item, config: settings.settings.itemConfig(for: item), bindings: bindings)
                    .tag(item)
            }
            .onMove { source, destination in
                let order = SettingsItemPresentation.reordered(
                    settings.settings.menuBarOrder, moving: Array(source), to: destination
                )
                settings.setMenuBarOrder(order)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let item = navigation.selected {
            SettingsItemDetail(item: item, settings: settings, monitor: monitor, speedTest: speedTest)
                .id(item)
        } else {
            Text("Select an item to configure it.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
