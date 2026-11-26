import AppKit
import SwiftUI

/// A light or dark menu bar specimen, 36 pt tall, holding one item's glyph.
struct SettingsPreviewTile: View {
    let image: NSImage
    let dark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(dark ? SettingsPalette.previewDark : SettingsPalette.previewLight)
            SettingsAppearanceImage(image: image, dark: dark)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(dark ? "Dark menu bar preview" : "Light menu bar preview")
    }
}

/// Shows an image under a fixed appearance. A template image takes its colour from the view it is drawn in, so the
/// view's appearance decides whether the glyph is drawn for a light or dark bar.
struct SettingsAppearanceImage: NSViewRepresentable {
    let image: NSImage
    let dark: Bool

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleNone
        view.imageAlignment = .alignCenter
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = image
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
}
