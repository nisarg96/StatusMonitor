import SwiftUI

/// The "Open at login" switch, with the last failure from changing it shown underneath.
struct PopoverLoginRow: View {
    let opensAtLogin: Bool
    let errorText: String?
    let onChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { opensAtLogin }, set: { onChange($0) })) {
                Text("Open at login")
                    .font(.system(size: 13))
                    .foregroundStyle(PopoverPalette.text)
            }
            .toggleStyle(.switch)
            if let errorText {
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
