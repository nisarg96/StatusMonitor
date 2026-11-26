import StatusMonitorCore
import SwiftUI

/**
 The speed test button, the running progress, and the result or failure. It is shared by the popover's Network card and
 the Settings Network section.

 It observes the shared view model, so the button and the results redraw as a run starts, progresses and ends.
 */
struct SpeedTestPanel: View {
    /// The shared speed test view model.
    @ObservedObject var model: SpeedTestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            controls
            outcome
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("Run speed test") { model.run() }
                .disabled(model.isRunning)
            if model.isRunning {
                Button("Cancel") { model.cancel() }
                Text(progressText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var outcome: some View {
        switch model.state {
        case let .done(result):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SpeedTestFormat.rows(for: result)) { row in
                    HStack(spacing: 8) {
                        Text(row.label)
                            .font(.system(size: 13))
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.system(size: 13))
                            .monospacedDigit()
                    }
                }
            }
        case let .failed(message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .idle, .running:
            EmptyView()
        }
    }

    /// The live phase and rate of a run, such as "Download 84.2 Mbit/s".
    private var progressText: String {
        guard case let .running(progress) = model.state else { return "" }
        switch progress {
        case .latency:
            return "Measuring latency"
        case let .download(mbps):
            return "Download \(SpeedTestFormat.rate(mbps))"
        case let .upload(mbps):
            return "Upload \(SpeedTestFormat.rate(mbps))"
        }
    }
}
