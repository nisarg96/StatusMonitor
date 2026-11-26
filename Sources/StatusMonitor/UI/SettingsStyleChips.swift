import StatusMonitorCore
import SwiftUI

/**
 The style chips.

 The selected chip is filled #1D1D1F in light mode. A style the item does not allow is greyed and cannot be picked.
 */
struct SettingsStyleChips: View {
    /// The menu bar item whose styles are offered.
    let item: MetricItemID
    /// The item's current style, which is drawn as selected.
    let selection: MenuBarItemStyle
    /// Called with the style that was picked.
    let onPick: (MenuBarItemStyle) -> Void

    var body: some View {
        let allowed = MenuBarItemConfig.allowedStyles(for: item)
        HStack(spacing: 6) {
            ForEach(SettingsItemPresentation.chipStyles(for: item), id: \.self) { style in
                chip(style, isAllowed: allowed.contains(style))
            }
        }
    }

    private func chip(_ style: MenuBarItemStyle, isAllowed: Bool) -> some View {
        let isSelected = style == selection
        return Button {
            onPick(style)
        } label: {
            Text(SettingsItemPresentation.styleLabel(style))
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? SettingsPalette.chipSelectedText : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isSelected ? SettingsPalette.chipSelected : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: isSelected ? 0 : 1))
                .opacity(isAllowed ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isAllowed)
    }
}
