import StatusMonitorCore
import SwiftUI

/// Disk: read and write rates, and a hoverable chart with read solid and write dashed.
struct PopoverDiskSection: View {
    let disk: DiskRates?
    let read: TimedSampleHistory
    let write: TimedSampleHistory
    let shown: Bool
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
