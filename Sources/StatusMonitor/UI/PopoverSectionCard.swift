import SwiftUI

/**
 One popover section as a card: a title with a show checkbox at the right, a divider, then the body.

 `shown` is nil for a section with no switch (Memory Clean). A section that is off keeps its header, so the user can
 switch it back on, and hides only its body.
 */
struct PopoverSectionCard<Body: View>: View {
    /// The section's heading.
    let title: String
    /// The checkbox state, or nil for a section with no switch.
    let shown: Bool?
    /// Called with the new state when the checkbox is pressed, or nil for a section with no switch.
    let onToggle: ((Bool) -> Void)?
    /// Builds the section's body, which is hidden while `shown` is false.
    @ViewBuilder let content: () -> Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if shown != false {
                Rectangle()
                    .fill(PopoverPalette.divider)
                    .frame(height: 1)
                content()
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(PopoverPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(PopoverPalette.cardBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PopoverPalette.secondaryText)
            Spacer(minLength: 8)
            if let shown, let onToggle {
                PopoverCheckbox(label: "Show \(title)", isOn: shown, action: onToggle)
            }
        }
    }
}

/**
 A 14 pt checkbox drawn in the accent colour.

 It is drawn as a symbol so the colour is the app's, not the system's.
 */
struct PopoverCheckbox: View {
    /// The accessibility label, such as "Show CPU and memory".
    let label: String
    /// The checkbox state.
    let isOn: Bool
    /// Called with the requested state when the checkbox is pressed.
    let action: (Bool) -> Void

    var body: some View {
        Button {
            action(!isOn)
        } label: {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 14))
                .foregroundStyle(isOn ? PopoverPalette.accent : PopoverPalette.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A label on the left, a monospaced value on the right.
struct PopoverValueRow: View {
    /// The label on the left.
    let label: String
    /// The value on the right, already formatted.
    let value: String
    /// The value's colour.
    var accent: Color = PopoverPalette.text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(PopoverPalette.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
    }
}

/// A 4 pt bar with a 2 pt radius. The fraction is clamped to 0...1.
struct PopoverBar: View {
    /// The filled share of the bar. Values outside 0...1 are clamped, and non-finite values draw empty.
    let fraction: Double
    /// The colour of the filled part.
    var fill: Color = PopoverPalette.fill

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(PopoverPalette.track)
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 4)
    }

    private var clamped: Double {
        guard fraction.isFinite else { return 0 }
        return min(1, max(0, fraction))
    }
}
