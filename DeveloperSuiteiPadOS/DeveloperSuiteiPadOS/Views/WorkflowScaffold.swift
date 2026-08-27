import SwiftUI

/// Replicates the title-bar / content / status-strip / action-button chrome
/// that `Developer-Suite-Android`'s `MainActivity.kt` repeats by hand in every
/// one of its five workflow composables (`ThermometerView`, `PulseOximeterView`,
/// `StethoscopeView`, `CameraView`, `EcgView`). Factored into one shared view
/// here since Swift doesn't need the duplication Compose has — this changes
/// nothing about what's rendered.
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

    private var statusBar: some View {
        Text(statusMessage)
            .font(.system(size: 16))
            .foregroundStyle(AndroidPalette.controlText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AndroidPalette.buttonFace)
    }
}

/// Standard Start/Stop/Record action button whose color follows Android's
/// `ActionState` (idle/busy/disabled) exactly — `ActionButtonIdle` /
/// `ActionButtonBusy` / `ActionButtonDisabled` from `AndroidPalette`.
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

/// Large centered reading display — matches Android's `ReadingBorder`
/// (`MainActivity.kt`), used for single big numeric/text readings (e.g.
/// Thermometer's Object Temp, Pulse Oximeter's SpO2 and pulse rate).
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
