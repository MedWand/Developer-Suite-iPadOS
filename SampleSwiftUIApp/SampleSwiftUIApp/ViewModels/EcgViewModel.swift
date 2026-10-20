import Foundation
import MedWandSDK

/// View model for the ECG workflow.
///
/// Monitoring starts as soon as the workflow is activated; only recording is started and stopped by the user,
/// with the button. The waveform itself is drawn by the SDK into ``AppViewModel/ecgDisplayLayer``. That layer
/// lives on ``AppViewModel``, and is registered once when connecting, because it is render state of the
/// controller, not state of this workflow.
@MainActor
final class EcgViewModel: ObservableObject {
    /// State of the Start/Stop Recording button.
    @Published var actionState: ActionState = .idle
    /// Monitoring or recording text, with the number of recordings captured so far.
    @Published var statusMessage = "Monitoring"

    private let controller: MedWandController
    private var monitorTask: Task<Void, Never>?
    // Recordings finished so far; shown in the status text.
    private var captured = 0

    init(controller: MedWandController) {
        self.controller = controller
    }

    /// The text of the action button.
    var buttonTitle: String {
        actionState == .busy ? "Stop Recording" : "Start Recording"
    }

    /// Starts ECG monitoring and installs the callback that receives each finished recording.
    func activate() {
        // Called by the SDK off the main actor, once per finished recording.
        let onStrip: @Sendable (Data) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.captured += 1
                self.updateStatus("Monitoring")
            }
        }
        monitorTask = Task {
            // The trace itself is drawn by the SDK into `AppViewModel.ecgDisplayLayer`; the readings arrive on
            // `onReadingReceived`, which `AppViewModel` receives and has no use for here. A finished recording
            // arrives on the module's `recordedStripReady`, assigned below (a new assignment replaces the
            // previous one, so activating again is harmless).
            guard let ecg = await controller.ecg else { return }
            ecg.recordedStripReady = onStrip
            do {
                if try await controller.startEcg() {
                    updateStatus("Monitoring")
                } else {
                    updateStatus("Could not start. Check the license and the MedWand connection.")
                }
            } catch {
                updateStatus("Error: \(error.localizedDescription)")
            }
        }
    }

    /// Stops any recording and the ECG monitoring.
    func deactivate() {
        monitorTask?.cancel(); monitorTask = nil
        if actionState == .busy {
            Task { await controller.stopRecording() }
        }
        Task { try? await controller.stopSensor() }
        actionState = .idle
        updateStatus("Not Monitoring")
    }

    /// Starts a recording when idle, stops it when busy, and ignores taps while a start or stop is in progress.
    func onActionButtonTapped() {
        switch actionState {
        case .idle: startCapture()
        case .busy: stopCapture()
        case .disabled: break
        }
    }

    private func startCapture() {
        actionState = .disabled
        Task {
            await controller.startRecording()
            actionState = .busy
            updateStatus("Monitoring")
        }
    }

    private func stopCapture() {
        actionState = .disabled
        Task {
            await controller.stopRecording()
            actionState = .idle
            updateStatus("Monitoring")
        }
    }

    private func updateStatus(_ value: String) {
        statusMessage = "\(value) [\(captured) Captured]"
    }
}
