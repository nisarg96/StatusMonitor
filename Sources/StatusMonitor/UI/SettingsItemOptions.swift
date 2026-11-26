import StatusMonitorCore
import SwiftUI

/// The option rows under the style: hide when idle (rates only), the warning threshold, and the click action.
struct SettingsItemOptions: View {
    /// The menu bar item being configured.
    let item: MetricItemID
    /// The item's current configuration, which decides which controls are enabled.
    let config: MenuBarItemConfig
    /// The bindings that the controls write through.
    let bindings: SettingsItemBindings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if SettingsItemPresentation.offersHideWhenIdle(item) {
                SettingsGroup(title: "Hide when idle") {
                    Toggle("Hide while idle", isOn: bindings.hideWhenIdle(item, config))
                    HStack(spacing: 8) {
                        Text("Idle below")
                        numberField(bindings.idleKB(item, config), width: 80)
                        Text("KB/s").foregroundStyle(.secondary)
                    }
                    .disabled(!config.hideWhenIdle)
                }
            }
            SettingsGroup(title: "Warning") {
                Toggle("Warn above a threshold", isOn: bindings.warningOn(item, config))
                HStack(spacing: 8) {
                    Text("Above")
                    numberField(bindings.warningValue(item), width: 80)
                    Text(SettingsItemPresentation.alertUnit(for: item)).foregroundStyle(.secondary)
                }
                .disabled(config.alertAbove == nil)
                Text("Above the threshold the item turns orange and shows a triangle with bold digits.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            SettingsGroup(title: "On click") {
                Picker("On click", selection: bindings.onClick(item, config)) {
                    Text("Show popover").tag(MenuBarClickAction.showPopover)
                    Text("Open Activity Monitor").tag(MenuBarClickAction.openActivityMonitor)
                    Text("Nothing").tag(MenuBarClickAction.nothing)
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }
        }
    }

    /**
     Returns a compact numeric text field.

     - Parameter value: The binding that the field reads and writes.
     - Parameter width: The field's width, in points.
     - Returns: The field.
     */
    private func numberField(_ value: Binding<Double>, width: CGFloat) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .labelsHidden()
    }
}
