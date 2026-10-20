import SwiftUI
import MedWandSDK

/// The stethoscope workflow: a "Mode" label over four mode buttons (Off, Heart, Lungs, Bowel), and a Start/Stop
/// Recording button. The selected mode is highlighted. There is no live audio-level meter.
struct StethoscopeView: View {
    @ObservedObject var viewModel: StethoscopeViewModel

    private static let modes: [MicrophoneMode] = [.off, .heart, .lungs, .bowel]

    var body: some View {
        WorkflowScaffold(
            title: "Stethoscope",
            statusMessage: viewModel.statusMessage
        ) {
            VStack(spacing: 16) {
                Text("Mode")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AndroidPalette.controlTextHighlight)
                HStack(spacing: 12) {
                    ForEach(Self.modes, id: \.self) { mode in
                        modeButton(mode)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } actionButton: {
            // The button is shown disabled whenever the mode is Off, in addition to whatever `actionState` says.
            // `onActionButtonTapped` also refuses to start a recording with the mode Off.
            WorkflowActionButton(
                title: viewModel.buttonTitle,
                state: (viewModel.actionState == .disabled || viewModel.mode == .off) ? .disabled : viewModel.actionState,
                action: viewModel.onActionButtonTapped
            )
        }
        .onAppear { viewModel.activate() }
        .onDisappear { viewModel.deactivate() }
    }

    private func modeButton(_ mode: MicrophoneMode) -> some View {
        Button {
            viewModel.selectMode(mode)
        } label: {
            Text(label(for: mode))
                .font(.system(size: 14))
                .foregroundStyle(AndroidPalette.controlText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(viewModel.mode == mode ? AndroidPalette.buttonFace : AndroidPalette.control)
        .disabled(viewModel.actionState == .disabled)
    }

    private func label(for mode: MicrophoneMode) -> String {
        switch mode {
        case .off: return "Off"
        case .heart: return "Heart"
        case .lungs: return "Lungs"
        case .bowel: return "Bowel"
        }
    }
}
