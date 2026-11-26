import StatusMonitorCore
import SwiftUI

/// The Settings sidebar: the live panes, then a greyed "Coming later" group that cannot be selected.
struct SettingsSidebar: View {
    /// The pane that is currently selected.
    let selection: SettingsPane
    /// Called with the tapped row.
    let onSelect: (SettingsSidebarItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPane.allCases, id: \.self) { pane in
                paneRow(pane)
            }
            Text("Coming later")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 18)
                .padding(.bottom, 4)
            ForEach(SettingsSidebarItem.comingLaterTitles, id: \.self) { title in
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isStaticText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SettingsPalette.sidebar)
    }

    private func paneRow(_ pane: SettingsPane) -> some View {
        let isSelected = pane == selection
        return Button {
            onSelect(.pane(pane))
        } label: {
            Text(pane.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? SettingsPalette.onAccent : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? SettingsPalette.accent : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
