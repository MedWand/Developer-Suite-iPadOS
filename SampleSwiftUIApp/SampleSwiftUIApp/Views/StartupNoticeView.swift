import SwiftUI

/// The BETA notice shown before the app connects. The Continue button accepts it and starts the connection.
struct StartupNoticeView: View {
    let onAccept: () -> Void

    // The notice shown to the user.
    private static let message = "This is a BETA only sample application and SDK. This is not intended for use in production and should only be used for initial development work. Camera testing requires camera permission. You will still need to request a license through your sales representative."

    var body: some View {
        VStack(spacing: 32) {
            Text(Self.message)
                .font(.system(size: 24))
                .lineSpacing(8)
                .foregroundStyle(AndroidPalette.controlText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button(action: onAccept) {
                Text("Continue")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AndroidPalette.buttonHighlight)
                    .frame(width: 220, height: 56)
            }
            .background(AndroidPalette.actionButtonIdle)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AndroidPalette.controlDark)
    }
}
