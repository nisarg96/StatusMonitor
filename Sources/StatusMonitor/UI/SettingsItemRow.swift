import StatusMonitorCore
import SwiftUI

/**
 One row of the menu bar item list.

 It shows a drag handle, the item's name with its style as the meta line, the priority, and the show toggle.
 */
struct SettingsItemRow: View {
    /// The menu bar item this row represents.
    let item: MetricItemID
    /// The item's configuration, which supplies the style shown in the meta line.
    let config: MenuBarItemConfig
    /// The bindings that the priority and show controls write through.
    let bindings: SettingsItemBindings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .accessibilityLabel("Drag handle")
            VStack(alignment: .leading, spacing: 1) {
                Text(SettingsItemPresentation.name(for: item))
                    .font(.system(size: 13))
                Text(SettingsItemPresentation.styleLabel(config.style))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Picker("Priority", selection: bindings.priority(item)) {
                ForEach(MenuBarPriority.allCases, id: \.self) { priority in
                    Text(priority.label).tag(priority)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            Toggle("Show \(SettingsItemPresentation.name(for: item)) in menu bar", isOn: bindings.shown(item))
                .labelsHidden()
                .disabled(!bindings.isSupported(item))
        }
        .padding(.vertical, 2)
    }
}
