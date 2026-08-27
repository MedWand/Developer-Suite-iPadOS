import SwiftUI

/// Fixed color palette matching `Developer-Suite-Android`'s `MainActivity.kt`
/// exactly (hex-for-hex), so this app's UI looks like the Android sample
/// rather than native iOS chrome. These are deliberately plain `Color`
/// constants, not semantic/dynamic colors — Android's theme has no dark-mode
/// variant, so this palette renders identically regardless of the iPad's
/// system appearance setting.
enum AndroidPalette {
    static let controlText = Color.black
    static let controlTextHighlight = Color.white
    static let control = Color(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF0 / 255)
    static let controlDark = Color(red: 0xA0 / 255, green: 0xA0 / 255, blue: 0xA0 / 255)
    static let controlDarkDark = Color(red: 0x40 / 255, green: 0x40 / 255, blue: 0x40 / 255)
    static let highlight = Color(red: 0x00 / 255, green: 0x78 / 255, blue: 0xD7 / 255)
    static let buttonHighlight = Color.white
    static let buttonFace = Color.white
    static let actionButtonIdle = Color(red: 0x00 / 255, green: 0xC0 / 255, blue: 0x00 / 255)
    static let actionButtonBusy = Color(red: 0xC0 / 255, green: 0x00 / 255, blue: 0x00 / 255)
    static let actionButtonDisabled = Color(red: 0x80 / 255, green: 0x80 / 255, blue: 0x80 / 255)
}
