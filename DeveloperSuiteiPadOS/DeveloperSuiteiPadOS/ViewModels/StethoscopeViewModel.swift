import Foundation
import MedWandSDK

@MainActor
final class StethoscopeViewModel: ObservableObject {
    @Published var mode: MicrophoneMode = .off
    @Published var actionState: ActionState = .idle
    @Published var statusMessage = "Off : Ready [0 Captured]"

    private let controller: MedWandController
    private var recordedTask: Task<Void, Never>?
    private var captured = 0

    init(controller: MedWandController) {
        self.controller = controller
    }

    var buttonTitle: String {
        actionState == .busy ? "Stop Recording" : "Start Recording"
    }

    func activate() {
        recordedTask = Task {
            guard let stethoscope = await controller.stethoscope else { return }
            for await pcm in await stethoscope.recordedAudioStream {
                await handleRecordedAudio(pcm)
            }
        }
    }

    func deactivate() {
        recordedTask?.cancel(); recordedTask = nil
        if actionState == .busy {
            Task { await controller.stopRecording() }
        }
        Task { _ = await controller.setStethoscopeMode(.off) }
        mode = .off
        actionState = .idle
    }

    func selectMode(_ newMode: MicrophoneMode) {
        if actionState == .busy { stopCapture() }
        Task {
            let ok = await controller.setStethoscopeMode(newMode)
            mode = ok ? newMode : .off
            updateStatus()
        }
    }

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
            await controller.stopRecording()
            actionState = .idle
            updateStatus()
        }
    }

    private func handleRecordedAudio(_ pcm: Data) async {
        // wavData(from:) is real on StethoscopeModule; the controller-level
        // convenience method (stethoscopeWavFromCapture) is currently a stub
        // — see docs/DESIGN.md's known-gaps section.
        if let wav = await controller.stethoscope?.wavData(from: pcm) {
            saveCapture(wav)
        }
        captured += 1
        updateStatus()
    }

    private func saveCapture(_ wav: Data) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("stethoscope-\(Date().timeIntervalSince1970).wav")
        try? wav.write(to: url)
    }

    private func updateStatus() {
        let stateText = actionState == .busy ? "Recording" : "Ready"
        statusMessage = "\(mode) : \(stateText) [\(captured) Captured]"
    }
}
