import SwiftUI

/// The ECG workflow: the live waveform filling the content area, and a Start/Stop Recording button. Monitoring
/// starts when the view appears and stops when it disappears.
///
/// The SDK draws the waveform into ``AppViewModel/ecgDisplayLayer``, which ``ECGWaveformView`` displays.
struct EcgView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var viewModel: EcgViewModel

    var body: some View {
        WorkflowScaffold(
            title: "ECG",
            statusMessage: viewModel.statusMessage
        ) {
            ECGWaveformView(layer: appViewModel.ecgDisplayLayer)
        } actionButton: {
            WorkflowActionButton(
                title: viewModel.buttonTitle,
                state: viewModel.actionState,
                action: viewModel.onActionButtonTapped
            )
        }
        .onAppear { viewModel.activate() }
        .onDisappear { viewModel.deactivate() }
    }
}
