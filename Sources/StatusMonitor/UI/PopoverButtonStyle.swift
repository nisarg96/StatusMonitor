import SwiftUI

/// Popover buttons. Primary is a solid fill; secondary is a white (or dark) fill with a border. Both have radius 6.
struct PopoverButtonStyle: ButtonStyle {
    /// True for the solid primary button, false for the bordered secondary one.
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? PopoverPalette.primaryText : PopoverPalette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? PopoverPalette.primaryFill : PopoverPalette.secondaryFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(PopoverPalette.secondaryBorder, lineWidth: prominent ? 0 : 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}
