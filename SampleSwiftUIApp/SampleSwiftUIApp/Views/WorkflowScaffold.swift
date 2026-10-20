import SwiftUI

/// The layout shared by every workflow screen, from top to bottom: a title bar, the workflow's content, a status
/// line, and the action button.
///
/// Each workflow view (``ThermometerView``, ``PulseOximeterView``, ``StethoscopeView``, ``CameraView`` and
/// ``EcgView``) supplies its title, status text, content and button, and this view arranges them. `contentBackground`
/// is the color behind the content: dark gray by default, black for the camera.
struct WorkflowScaffold<Content: View, ActionButton: View>: View {
    let title: String
    var contentBackground: Color = AndroidPalette.controlDarkDark
    let statusMessage: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actionButton: () -> ActionButton

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(contentBackground)
            statusBar
            actionButton()
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
    }

    /// The blue bar with the workflow's name.
    private var titleBar: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AndroidPalette.buttonHighlight)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(AndroidPalette.highlight)
    }

    /// The line under the content that shows the workflow's status message.
    private var statusBar: some View {
        Text(statusMessage)
            .font(.system(size: 16))
            .foregroundStyle(AndroidPalette.controlText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AndroidPalette.buttonFace)
    }
}

/// The action button every workflow shows at the bottom. Its color follows its ``ActionState``: green when idle,
/// red when busy, and gray when disabled, in which case it also ignores taps.
struct WorkflowActionButton: View {
    let title: String
    let state: ActionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(color)
        .disabled(state == .disabled)
    }

    private var color: Color {
        switch state {
        case .idle: AndroidPalette.actionButtonIdle
        case .busy: AndroidPalette.actionButtonBusy
        case .disabled: AndroidPalette.actionButtonDisabled
        }
    }
}

/// A large, centered reading on a dark background. Used for single big values: the thermometer's temperature and
/// the pulse oximeter's SpO2 and pulse rate.
struct ReadingBorder: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 64))
            .foregroundStyle(AndroidPalette.controlTextHighlight)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AndroidPalette.controlDarkDark)
    }
}
