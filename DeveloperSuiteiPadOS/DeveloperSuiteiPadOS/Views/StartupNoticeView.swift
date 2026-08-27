import SwiftUI

/// BETA gate shown before the app attempts to connect. Matches Android's
/// `StartupNotice` composable (`Developer-Suite-Android/MainActivity.kt`)
/// exactly: wording, dark-gray background, green Continue button.
struct StartupNoticeView: View {
    let onAccept: () -> Void

    // Matches Android's StartupNoticeMessage verbatim, except "Android camera
    // permission" → "camera permission" — the original names the wrong
    // platform when copied as-is into an iPadOS app.
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
