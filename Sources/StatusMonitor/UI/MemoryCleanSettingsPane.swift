import StatusMonitorCore
import SwiftUI

/**
 The Memory Clean page: the note, the administrator approval, Auto Clean with its threshold, the two clean cards,
 and the recent cleans.
 */
struct MemoryCleanSettingsPane: View {
    /// The settings, which hold the Auto Clean switch and threshold.
    @ObservedObject var settings: SettingsViewModel
    /// The purge approval state shown by the approval row.
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
            GeometryReader { geometry in
                ForEach(Array(AutoCleanThreshold.stops.enumerated()), id: \.offset) { index, stop in
                    Text("\(stop)%")
                        .fixedSize()
                        .position(x: Self.tickX(index: index, count: AutoCleanThreshold.stops.count,
                                                width: geometry.size.width),
                                  y: geometry.size.height / 2)
                }
            }
            .frame(height: 14)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    /**
     The x position, in points, of a tick label's centre. It matches the slider's tick for that stop, which sits at
     an equal fraction of the track width.

     - Parameters:
       - index: The stop's position in the list, starting at 0.
       - count: The number of stops.
       - width: The width of the track.
     - Returns: The x position of the label's centre.
     */
    static func tickX(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(count - 1)
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
