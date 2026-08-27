import Foundation

/// Drives each workflow's primary action button. Mirrors Android's app-local
/// `ActionState` enum — distinct from the SDK's `MedWandReadingState`.
enum ActionState {
    case idle
    case busy
    case disabled
}
