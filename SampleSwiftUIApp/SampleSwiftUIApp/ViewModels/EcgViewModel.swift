import Foundation
import UIKit
import MedWandSDK

/// View model for the ECG workflow.
///
/// Monitoring starts as soon as the workflow is activated; only recording is started and stopped by the user,
/// with the button. The waveform itself is drawn by the SDK into ``AppViewModel/ecgDisplayLayer``. That layer
/// lives on ``AppViewModel``, and is registered once when connecting, because it is render state of the
/// controller, not state of this workflow.
///
/// A finished recording arrives on the ECG module's `recordedStripReady` callback as the bytes of a BMP file. It is saved
/// twice, as a PNG in `ecg-captures` in the app's Documents folder, and as a line in `captures.txt` in the same folder (the
/// time and the `data:image/bmp;base64,` text, as the Windows sample writes it). A recording counts as captured when at
/// least one of the two was written.
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
        // Called by the SDK off the main actor, once per finished recording. The files can be several megabytes, so they
        // are written off the main actor too, and only the count and the status come back to it.
        let onStrip: @Sendable (Data) -> Void = { [weak self, controller] bmp in
            Task {
                let dataURI = await controller.ecgBmpFromCapture(bytes: bmp)
                let saved = await Task.detached(priority: .utility) {
                    EcgCaptureStore.save(bmp: bmp, dataURI: dataURI)
                }.value
                await self?.stripSaved(saved)
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

    // A recording was written (or not): it counts only if something was kept.
    private func stripSaved(_ saved: Bool) {
        if saved {
            captured += 1
            updateStatus("Monitoring")
        } else {
            updateStatus("Error: could not save the strip")
        }
    }

    private func updateStatus(_ value: String) {
        statusMessage = "\(value) [\(captured) Captured]"
    }
}

/// Writes a finished ECG recording to the app's Documents folder.
private enum EcgCaptureStore {
    /// Saves the strip as `ecg-captures/ecg-<time>.png` and appends its data URI to `captures.txt`.
    /// - Returns: `true` if at least one of the two was written.
    nonisolated static func save(bmp: Data, dataURI: String?) -> Bool {
        let savedPNG = savePNG(from: bmp)
        var appended = false
        if let dataURI { appended = appendLine(dataURI: dataURI) }
        return savedPNG || appended
    }

    nonisolated private static var documents: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // Converts the BMP the SDK delivers to PNG and writes it in `ecg-captures`, creating the folder if needed.
    nonisolated private static func savePNG(from bmp: Data) -> Bool {
        guard let dir = documents?.appendingPathComponent("ecg-captures", isDirectory: true),
              let png = UIImage(data: bmp)?.pngData() else { return false }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try png.write(to: dir.appendingPathComponent("ecg-\(Date().timeIntervalSince1970).png"))
            return true
        } catch {
            return false
        }
    }

    // Appends `[<UTC time>] -> <data URI>` and a newline to `captures.txt`, keeping what is already there.
    nonisolated private static func appendLine(dataURI: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let url = documents?.appendingPathComponent("captures.txt"),
              let data = "[\(formatter.string(from: Date()))] -> \(dataURI)\n".data(using: .utf8) else { return false }
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                try data.write(to: url)
                return true
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }
}
