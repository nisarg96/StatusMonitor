import StatusMonitorCore
import SwiftUI

/// Memory Clean: Standard and Extreme buttons, the Auto Clean switch, the last clean's result, and what a clean does.
/// The buttons are disabled while a clean runs, or when no clean action is wired up.
struct PopoverCleanSection: View {
    let autoCleanOn: Bool
    let thresholdPercent: Int
    let canClean: Bool
    let isCleaning: Bool
    /// The "Last clean freed X, N min ago" line. Nil hides it.
    let lastLine: String?
    let onClean: (CleanPreset) -> Void
    let onAutoClean: (Bool) -> Void

    var body: some View {
        PopoverSectionCard(title: "Memory Clean", shown: nil, onToggle: nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Standard clean") { onClean(.standard) }
                        .buttonStyle(PopoverButtonStyle(prominent: true))
                    Button("Extreme clean") { onClean(.extreme) }
                        .buttonStyle(PopoverButtonStyle(prominent: false))
                }
                .disabled(!canClean || isCleaning)

                Toggle(isOn: Binding(get: { autoCleanOn }, set: { onAutoClean($0) })) {
                    Text("Auto Clean at \(thresholdPercent)%")
                        .font(.system(size: 13))
                        .foregroundStyle(PopoverPalette.text)
                }
                .toggleStyle(.switch)

                if let lastLine {
                    Text(lastLine)
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverPalette.secondaryText)
                }
                Text("Frees inactive file cache only. Memory used by open apps stays as it is.")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverPalette.secondaryText)
            }
        }
    }
}
