import StatusMonitorCore
import SwiftUI

/**
 Watches the Memory Clean view model, so the buttons and the last-clean line redraw when a clean starts or ends.

 It passes plain values down to `PopoverCleanSection`.
 */
struct PopoverCleanObserver: View {
    /// The clean view model that is observed.
    @ObservedObject var clean: MemoryCleanViewModel
    /// The Auto Clean switch state.
    let autoCleanOn: Bool
    /// The Auto Clean threshold, in percent.
    let thresholdPercent: Int
    /// Called with the new Auto Clean state when the switch changes.
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
