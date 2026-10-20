import Foundation

/// The state of a workflow's primary action button (Start/Stop, Start/Stop Recording, Capture).
///
/// This is the app's own UI state. It is separate from the SDK's `MedWandReadingState`, which describes the
/// sensor session rather than the button.
enum ActionState {
    /// Ready to start; the button is green.
    case idle
    /// The action is running and a tap stops it; the button is red.
    case busy
    /// A start or stop is in progress, or the action is unavailable; the button ignores taps and is gray.
    case disabled
}
