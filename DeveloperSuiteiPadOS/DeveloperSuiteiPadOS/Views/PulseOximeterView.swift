import SwiftUI

/// Matches Android's `PulseOximeterView` composable (`MainActivity.kt`)
/// exactly: title bar, two stacked readings (SpO2, then Pulse Rate) split by
/// a thin dark divider, status strip, Start/Stop action button.
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
