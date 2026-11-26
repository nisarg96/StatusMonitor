import SwiftUI

/**
 A popover section made of plain value rows, each optionally with a bar.

 It is used by GPU, memory pressure, battery and thermal. The caller decides which rows exist, so a missing reading
 never becomes a row.
 */
struct PopoverMetricSection: View {
    /// One value row, with an optional bar under it.
    struct Line: Identifiable {
        /// The row's identifier, which also keys it in the list.
        let id: String
        /// The label on the left of the row.
        let label: String
        /// The value on the right of the row, already formatted.
        let value: String
        /// The value's colour.
        var accent: Color = PopoverPalette.text
        /// Draws a bar under the row when set. Clamped to 0...1.
        var bar: Double?
    }

    /// The section's heading.
    let title: String
    /// The section's checkbox state, or nil for a section with no switch.
    let shown: Bool?
    /// Called with the new visibility when the checkbox changes, or nil for a section with no switch.
    let onToggle: ((Bool) -> Void)?
    /// The rows to draw, in order.
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
