import Foundation
import MedWandSDK

/// Monitoring auto-starts on activation, matching Android
/// (`Developer-Suite-Android/docs/DESIGN.md` §6.5) — only the record button
/// is click-gated. The `ECGRenderTarget` itself lives on `AppViewModel`
/// (registered once, at connect time, not per-activation) since it's a
/// controller-level render target, not workflow-scoped state.
@MainActor
final class EcgViewModel: ObservableObject {
    @Published var actionState: ActionState = .idle
    @Published var statusMessage = "Monitoring"

    private let controller: MedWandController
    private var monitorTask: Task<Void, Never>?
    private var stripTask: Task<Void, Never>?
    private var captured = 0

    init(controller: MedWandController) {
        self.controller = controller
    }

    var buttonTitle: String {
        actionState == .busy ? "Stop Recording" : "Start Recording"
    }

    func activate() {
        monitorTask = Task {
            do {
                let stream = try await controller.startECG()
                updateStatus("Monitoring")
                for await _ in stream { /* frames render via ECGRenderTarget */ }
            } catch {
                updateStatus("Error: \(error.localizedDescription)")
            }
        }
        stripTask = Task {
            guard let ecg = await controller.ecg else { return }
            for await _ in await ecg.recordedStripStream {
                captured += 1
                updateStatus("Monitoring")
            }
        }
    }

    func deactivate() {
        monitorTask?.cancel(); monitorTask = nil
        stripTask?.cancel(); stripTask = nil
        if actionState == .busy {
            Task { await controller.stopRecording() }
        }
        Task { try? await controller.stopSensor() }
        actionState = .idle
        updateStatus("Not Monitoring")
    }

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
