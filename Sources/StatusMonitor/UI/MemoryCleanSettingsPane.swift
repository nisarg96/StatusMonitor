import StatusMonitorCore
import SwiftUI

/// The Memory Clean page: the note, the administrator approval, Auto Clean with its threshold, the two clean cards,
/// and the recent cleans.
struct MemoryCleanSettingsPane: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var purge: PurgePermissionViewModel
    /// Nil until the clean use case is wired in. Then the cards show no Clean now button and no list.
    let memoryClean: MemoryCleanViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                noteBox
                MemoryCleanApprovalRow(purge: purge)
                autoCleanSection
                cards
                if let memoryClean {
                    MemoryCleanRecentList(model: memoryClean)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { purge.refresh() }
    }

    private var noteBox: some View {
        Text("Purge releases inactive file cache. It does not free wired memory or stop runaway processes.")
            .font(.system(size: 12))
            .foregroundStyle(SettingsPalette.noteText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(SettingsPalette.noteFill))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsPalette.noteBorder))
    }

    private var autoCleanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Auto Clean", isOn: Binding(
                get: { settings.settings.autoCleanEnabled },
                set: { settings.setAutoCleanEnabled($0) }
            ))
            Text(MemoryCleanSummary.sentence(
                thresholdPercent: settings.settings.autoCleanThresholdPercent,
                physicalBytes: ProcessInfo.processInfo.physicalMemory
            ))
            .font(.system(size: 13))
            thresholdSlider
            Text("Auto Clean runs Standard Clean at that point. It waits at least \(MemoryCleanSummary.cooldownText) "
                + "between cleans.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var thresholdSlider: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { Double(settings.settings.autoCleanThresholdPercent) },
                set: { settings.setAutoCleanThresholdPercent(Int($0.rounded())) }
            ),
            in: Double(AutoCleanThreshold.minimumPercent)...Double(AutoCleanThreshold.maximumPercent),
            step: Double(AutoCleanThreshold.stepPercent))
            .disabled(!settings.settings.autoCleanEnabled)
            HStack(spacing: 0) {
                ForEach(AutoCleanThreshold.stops, id: \.self) { stop in
                    Text("\(stop)%").frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var cards: some View {
        if let memoryClean {
            MemoryCleanLiveCards(model: memoryClean)
        } else {
            MemoryCleanCards(isBusy: false, onClean: nil)
        }
    }
}
