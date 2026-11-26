import StatusMonitorCore
import SwiftUI

/// The administrator approval for purge: its state as a pill, and the button that installs or removes it.
struct MemoryCleanApprovalRow: View {
    /// The purge approval state, which drives the pill and the button.
    @ObservedObject var purge: PurgePermissionViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Administrator approval")
                    .font(.system(size: 13, weight: .medium))
                Text("Memory Clean runs purge with a one-time approval.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if case .failed(let message) = purge.state {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 12)
            statusPill
            actionButton
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
    }

    @ViewBuilder
    private var statusPill: some View {
        switch purge.state {
        case .installed:
            pill("✓ Installed", fill: SettingsPalette.pillFill, text: SettingsPalette.pillText)
        case .notInstalled, .failed:
            pill("Not installed", fill: Color(nsColor: .quaternaryLabelColor), text: Color.secondary)
        case .working:
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch purge.state {
        case .installed:
            Button("Remove") { purge.uninstall() }
        case .notInstalled, .failed:
            Button("Install…") { purge.install() }
        case .working:
            EmptyView()
        }
    }

    private func pill(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill))
    }
}
