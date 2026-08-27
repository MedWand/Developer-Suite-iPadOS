import SwiftUI

/// Matches Android's `EcgView` composable (`MainActivity.kt`): title bar,
/// full-bleed waveform display against the dark content background, status
/// strip, recording action button. Waveform rendering itself (`ECGModule` →
/// `ECGRenderTargetImpl` → `ECGWaveformView`) is unchanged by this reskin.
struct EcgView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var viewModel: EcgViewModel

    var body: some View {
        WorkflowScaffold(
            title: "ECG",
            statusMessage: viewModel.statusMessage
        ) {
            ECGWaveformView(image: appViewModel.ecgFrameImage)
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
