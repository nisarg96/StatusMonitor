import StatusMonitorCore
import SwiftUI

/// Watches the Memory Clean view model, so the buttons and the last-clean line redraw when a clean starts or ends.
/// Passes plain values down to `PopoverCleanSection`.
struct PopoverCleanObserver: View {
    @ObservedObject var clean: MemoryCleanViewModel
    let autoCleanOn: Bool
    let thresholdPercent: Int
    let onAutoClean: (Bool) -> Void

    var body: some View {
        PopoverCleanSection(
            autoCleanOn: autoCleanOn,
            thresholdPercent: thresholdPercent,
            canClean: true,
            isCleaning: clean.isCleaning,
            lastLine: PopoverCleanLine.text(latest: clean.recent.first, now: Date()),
            onClean: { clean.clean($0) },
            onAutoClean: onAutoClean
        )
    }
}
