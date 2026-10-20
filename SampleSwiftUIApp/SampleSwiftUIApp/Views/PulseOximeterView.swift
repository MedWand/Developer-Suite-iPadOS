import SwiftUI

/// The pulse oximeter workflow: two large readings, SpO2 above pulse rate, separated by a thin divider, and a
/// Start/Stop button. It is driven by a ``SimpleSensorViewModel``.
struct PulseOximeterView: View {
    @ObservedObject var viewModel: SimpleSensorViewModel

    var body: some View {
        WorkflowScaffold(
            title: "Pulse Oximeter",
            statusMessage: viewModel.statusMessage
        ) {
            VStack(spacing: 0) {
                ReadingBorder(text: viewModel.lastReading?.spo2.map { "\($0)%" } ?? "—")
                Rectangle()
                    .fill(AndroidPalette.controlDarkDark)
                    .frame(height: 5)
                ReadingBorder(text: viewModel.lastReading?.pulseRate.map { "\($0) BPM" } ?? "—")
            }
        } actionButton: {
            WorkflowActionButton(
                title: viewModel.buttonTitle,
                state: viewModel.actionState,
                action: viewModel.onActionButtonTapped
            )
        }
    }
}
