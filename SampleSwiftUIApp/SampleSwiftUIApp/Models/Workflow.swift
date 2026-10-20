import Foundation

/// One of the five sensor workflows the toolbar can select.
///
/// ``AppViewModel/selectedWorkflow`` holds the current one (`nil` shows the "Select a workflow" placeholder), and
/// ``AppViewModel/toolbarEnabled`` says which workflows the connected MedWand and license can use.
enum Workflow: String, CaseIterable, Identifiable {
    case thermometer
    case pulseOximeter
    case stethoscope
    case camera
    case ecg

    var id: String { rawValue }

    /// The name shown to the user.
    var displayName: String {
        switch self {
        case .thermometer: return "Thermometer"
        case .pulseOximeter: return "Pulse Oximeter"
        case .stethoscope: return "Stethoscope"
        case .camera: return "Camera"
        case .ecg: return "ECG"
        }
    }

    /// The name of this workflow's toolbar icon in the asset catalog (`Assets.xcassets`).
    var toolbarIconName: String {
        switch self {
        case .thermometer: return "temperature_hover"
        case .pulseOximeter: return "spo2_hover"
        case .stethoscope: return "stethoscope_hover"
        case .camera: return "camera_hover"
        case .ecg: return "ecg_hover"
        }
    }
}
