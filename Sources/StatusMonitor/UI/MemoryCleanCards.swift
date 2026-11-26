import StatusMonitorCore
import SwiftUI

/**
 The Standard and Extreme clean cards.

 `onClean` nil hides the Clean now buttons.
 */
struct MemoryCleanCards: View {
    /// Disables the Clean now buttons while a clean runs.
    let isBusy: Bool
    /// Runs the clean for a preset, or nil to hide the buttons.
    let onClean: ((CleanPreset) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemoryCleanCard(
                title: "Standard clean",
                description: "Purges inactive file cache once. Quick, and open apps keep running.",
                isBusy: isBusy,
                action: onClean.map { clean in { clean(.standard) } }
            )
            MemoryCleanCard(
                title: "Extreme clean",
                description: "Purges, runs memory_pressure -l warn, then purges again. Frees more and takes longer.",
                isBusy: isBusy,
                action: onClean.map { clean in { clean(.extreme) } }
            )
        }
    }
}

/// The same cards, observing the clean view model so the buttons disable while a clean runs.
struct MemoryCleanLiveCards: View {
    /// The clean view model whose `isCleaning` state disables the buttons.
    @ObservedObject var model: MemoryCleanViewModel

    var body: some View {
        MemoryCleanCards(isBusy: model.isCleaning, onClean: { model.clean($0) })
    }
}

/// One clean: a title, a one-line description, and a Clean now button when cleaning is connected.
struct MemoryCleanCard: View {
    /// The card's heading, such as "Standard clean".
    let title: String
    /// A one-line description of what the clean does.
    let description: String
    /// Disables the Clean now button while a clean runs.
    let isBusy: Bool
    /// The Clean now action, or nil to hide the button.
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let action {
                Button("Clean now", action: action)
                    .disabled(isBusy)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: .separatorColor)))
    }
}
