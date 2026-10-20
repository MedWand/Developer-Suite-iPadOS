import Foundation
import MedWandSDK

/// View model for the stethoscope workflow: choose a listening mode (heart, lungs or bowel), then record.
///
/// A finished recording arrives through the stethoscope module's `recordedFramesReady` callback, is converted to
/// WAV, and is saved in the app's Documents folder.
@MainActor
final class StethoscopeViewModel: ObservableObject {
    /// The selected microphone mode. `.off` until the user picks one.
    @Published var mode: MicrophoneMode = .off
    /// State of the Start/Stop Recording button.
    @Published var actionState: ActionState = .idle
    /// Mode and recording text, with the number of recordings captured so far.
    @Published var statusMessage = "Off : Ready [0 Captured]"

    private let controller: MedWandController
    private var captured = 0

    // `StethoscopeModule.recordedFramesReady` is a callback on the module, which lives as long as the
    // controller. It is assigned once (`installRecordingCallback()`) and stays assigned across workflow
    // activations; `deactivate()` leaves it in place.
    private var recordingCallbackInstalled = false

    init(controller: MedWandController) {
        self.controller = controller
    }

    /// The text of the action button.
    var buttonTitle: String {
        actionState == .busy ? "Stop Recording" : "Start Recording"
    }

    /// Nothing to do on activation: the microphone is turned on when the user selects a mode.
    func activate() {}

    /// Assigns the module's `recordedFramesReady` callback. Call it after `configure(...)` has created the
    /// module. Safe to call again (for example after Retry): it only installs once. Does nothing if the license
    /// has no stethoscope module.
    ///
    /// The SDK calls the closure off the main actor, once per finished recording. A recording that finishes
    /// while no callback is assigned is dropped, so this is installed before any recording can start.
    func installRecordingCallback() async {
        guard !recordingCallbackInstalled, let module = await controller.stethoscope else { return }
        recordingCallbackInstalled = true
        module.recordedFramesReady = { [weak self] pcm in
            Task { @MainActor in await self?.handleRecordedAudio(pcm) }
        }
    }

    /// Stops any recording and turns the microphone off.
    func deactivate() {
        if actionState == .busy {
            Task { await controller.stopRecording() }
        }
        Task { _ = try? await controller.setStethoscopeMode(.off) }
        mode = .off
        actionState = .idle
    }

    /// Sets the microphone mode, stopping a recording in progress first. On failure it shows an error and goes back to Off.
    func selectMode(_ newMode: MicrophoneMode) {
        if actionState == .busy { stopCapture() }
        Task {
            do {
                // `true` when the mode was set (including `.off`). This app does not use the live audio, so it
                // never assigns `stethoscope.frameReady`; live audio is then read and dropped by the SDK.
                guard try await controller.setStethoscopeMode(newMode) else {
                    mode = .off
                    statusMessage = "Error: could not set the stethoscope mode."
                    return
                }
                mode = newMode
                updateStatus()
            } catch {
                mode = .off
                statusMessage = "Error: \(describe(error))"
            }
        }
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
        guard mode != .off else {
            statusMessage = "Select Heart, Lungs, or Bowel before recording."
            return
        }
        actionState = .disabled
        Task {
            await controller.startRecording()
            actionState = .busy
            updateStatus()
        }
    }

    private func stopCapture() {
        actionState = .disabled
        Task {
            // The recording arrives on `recordedFramesReady` and is saved by the callback installed above.
            await controller.stopRecording()
            actionState = .idle
            updateStatus()
        }
    }

    // Converts the recorded audio to a WAV file and saves it. The SDK returns the WAV as a base64 data URI.
    private func handleRecordedAudio(_ pcm: Data) async {
        if let wavDataURI = await controller.stethoscopeWavFromCapture(bytes: pcm),
           let base64 = wavDataURI.components(separatedBy: ",").last,
           let wav = Data(base64Encoded: base64, options: .ignoreUnknownCharacters), !wav.isEmpty {
            saveCapture(wav)
        }
        captured += 1
        updateStatus()
    }

    // Writes the recording to the app's Documents folder as `stethoscope-<time>.wav`.
    private func saveCapture(_ wav: Data) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("stethoscope-\(Date().timeIntervalSince1970).wav")
        try? wav.write(to: url)
    }

    // A short description of an error for the status line.
    private func describe(_ error: Error) -> String {
        guard let deviceError = error as? MedWandDeviceError else { return error.localizedDescription }
        return deviceError.message.isEmpty ? "\(deviceError.code)" : "\(deviceError.code): \(deviceError.message)"
    }

    private func updateStatus() {
        let stateText = actionState == .busy ? "Recording" : "Ready"
        statusMessage = "\(mode) : \(stateText) [\(captured) Captured]"
    }
}
