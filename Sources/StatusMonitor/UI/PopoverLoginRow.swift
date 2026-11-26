import StatusMonitorCore
import SwiftUI

/// The "Open at login" switch, with the last failure from changing it shown underneath.
struct PopoverLoginRow: View {
    /// The settings model that holds the login item state. Observed, so the switch redraws when the state changes.
    @ObservedObject var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { settings.opensAtLogin }, set: { settings.setOpensAtLogin($0) })) {
                Text("Open at login")
                    .font(.system(size: 13))
                    .foregroundStyle(PopoverPalette.text)
            }
            .toggleStyle(.switch)
            if let errorText = settings.loginItemError {
                Text(errorText)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverPalette.critical)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(PopoverPalette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PopoverPalette.cardBorder, lineWidth: 1))
    }
}
