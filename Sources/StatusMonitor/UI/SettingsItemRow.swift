import StatusMonitorCore
import SwiftUI

/// One row of the menu bar item list: drag handle, name with its style as the meta line, priority, and show toggle.
struct SettingsItemRow: View {
    let item: MetricItemID
    let config: MenuBarItemConfig
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
