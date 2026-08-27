import Foundation

/// One of the five sensor workflows the toolbar can select, mirroring
/// Android's five `ISensorView` implementations.
enum Workflow: String, CaseIterable, Identifiable {
    case thermometer
    case pulseOximeter
    case stethoscope
    case camera
    case ecg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thermometer: return "Thermometer"
        case .pulseOximeter: return "Pulse Oximeter"
        case .stethoscope: return "Stethoscope"
        case .camera: return "Camera"
        case .ecg: return "ECG"
        }
    }

    /// Asset catalog name of the Android toolbar icon for this workflow —
    /// see `AndroidPalette` and `Developer-Suite-Android`'s `MainActivity.kt`
    /// `ToolBar` composable, which this app's toolbar matches icon-for-icon.
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
