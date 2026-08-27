import SwiftUI
import MedWandSDK

/// Matches Android's `StethoscopeView` composable (`MainActivity.kt`)
/// exactly: title bar, centered "Mode" label with 4 mode buttons (Off /
/// Heart / Lungs / Bowel — Android has no live audio-level meter), status
/// strip, Start/Stop action button.
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
            // Matches the prior behavior this reskin preserves: the action
            // button is visually disabled whenever mode is Off, in addition
            // to whatever `actionState` itself says — `onActionButtonTapped`
            // guards against starting with mode Off regardless.
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
