import SwiftUI

/// A labelled block of controls in a detail pane: a 12 pt semibold title over its content.
struct SettingsGroup<Content: View>: View {
    /// The block's heading.
    let title: String
    /// The controls under the heading.
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
