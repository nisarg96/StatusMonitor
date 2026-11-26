import StatusMonitorCore
import SwiftUI

/// The recent cleans, newest first: time, type and memory freed.
struct MemoryCleanRecentList: View {
    @ObservedObject var model: MemoryCleanViewModel

    var body: some View {
        SettingsGroup(title: "Recent cleans") {
            if model.recent.isEmpty {
                Text("No cleans yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                let rows = RecentCleanRows.rows(model.recent) { $0.formatted(date: .omitted, time: .shortened) }
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("Time")
                        Text("Type")
                        Text("Freed")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            Text(row.time)
                            Text(row.type)
                            Text(row.freed).monospacedDigit()
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
    }
}
