import SwiftUI

/// A popover section made of plain value rows, each optionally with a bar. Used by GPU, memory pressure,
/// battery and thermal. The caller decides which rows exist, so a missing reading never becomes a row.
struct PopoverMetricSection: View {
    struct Line: Identifiable {
        let id: String
        let label: String
        let value: String
        var accent: Color = PopoverPalette.text
        /// Draws a bar under the row when set. Clamped to 0...1.
        var bar: Double?
    }

    let title: String
    let shown: Bool?
    let onToggle: ((Bool) -> Void)?
    let lines: [Line]

    var body: some View {
        PopoverSectionCard(title: title, shown: shown, onToggle: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines) { line in
                    PopoverValueRow(label: line.label, value: line.value, accent: line.accent)
                    if let bar = line.bar {
                        PopoverBar(fraction: bar)
                    }
                }
            }
        }
    }
}
