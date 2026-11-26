import StatusMonitorCore
import SwiftUI

/// Disk: read and write rates, and a hoverable chart with read solid and write dashed.
struct PopoverDiskSection: View {
    /// The latest disk rates, or nil when there are none.
    let disk: DiskRates?
    /// The read-rate history charted as a solid line.
    let read: TimedSampleHistory
    /// The write-rate history charted as a dashed line.
    let write: TimedSampleHistory
    /// The section's checkbox state.
    let shown: Bool
    /// Called with the new visibility when the section's checkbox changes.
    let onToggle: (Bool) -> Void

    var body: some View {
        PopoverSectionCard(title: "Disk", shown: shown, onToggle: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                if let disk {
                    PopoverValueRow(label: "↓ Read", value: Format.rate(disk.readBps))
                    PopoverValueRow(label: "↑ Write", value: Format.rate(disk.writeBps))
                }
                if !read.samples.isEmpty {
                    ChartHoverChart(
                        lines: [
                            ChartLine(id: "read", history: read, color: PopoverPalette.fill),
                            ChartLine(id: "write", history: write, color: PopoverPalette.download, dashed: true)
                        ],
                        yDomain: nil,
                        tooltip: { index in
                            guard let readBps = read.value(at: index), let writeBps = write.value(at: index) else {
                                return []
                            }
                            return ChartTooltipText.disk(readBps: readBps, writeBps: writeBps)
                        }
                    )
                }
            }
        }
    }
}
