import SwiftUI

/// The fixed color palette used by every view in the app.
///
/// These are plain `Color` constants, not semantic or dynamic colors, so the UI looks the same whatever the iPad's
/// light/dark appearance setting is. Names follow the role of a color (a control face, a title-bar highlight, an
/// action-button state) rather than its hue.
enum AndroidPalette {
    /// Text on a light control or panel.
    static let controlText = Color.black
    /// Text on a dark control or panel: readings and labels on dark backgrounds.
    static let controlTextHighlight = Color.white
    /// Light gray face of the toolbar and unselected buttons. `#F0F0F0`.
    static let control = Color(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF0 / 255)
    /// Mid gray used for the app background and the camera Modes panel. `#A0A0A0`.
    static let controlDark = Color(red: 0xA0 / 255, green: 0xA0 / 255, blue: 0xA0 / 255)
    /// Dark gray used behind readings and for the status bar. `#404040`.
    static let controlDarkDark = Color(red: 0x40 / 255, green: 0x40 / 255, blue: 0x40 / 255)
    /// Blue used for title bars and the Modes heading. `#0078D7`.
    static let highlight = Color(red: 0x00 / 255, green: 0x78 / 255, blue: 0xD7 / 255)
    /// White text on a colored title bar or button.
    static let buttonHighlight = Color.white
    /// White face of selected and secondary buttons and of the status line.
    static let buttonFace = Color.white
    /// Action button color when the action can be started (green). `#00C000`.
    static let actionButtonIdle = Color(red: 0x00 / 255, green: 0xC0 / 255, blue: 0x00 / 255)
    /// Action button color while the action is running (red). `#C00000`.
    static let actionButtonBusy = Color(red: 0xC0 / 255, green: 0x00 / 255, blue: 0x00 / 255)
    /// Action button color when it cannot be used (gray). `#808080`.
    static let actionButtonDisabled = Color(red: 0x80 / 255, green: 0x80 / 255, blue: 0x80 / 255)
}
