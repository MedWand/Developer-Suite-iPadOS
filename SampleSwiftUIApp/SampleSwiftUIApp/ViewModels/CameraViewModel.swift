import Foundation
import UIKit
import MedWandSDK

/// `CameraPreviewTarget` is an empty marker protocol with no accessible
/// initializer of its own — a concrete conformer is required to instantiate it.
private struct SimpleCameraPreviewTarget: CameraPreviewTarget {}

/// View model for the camera workflow: choose a mode (off, dermatoscope or otoscope), watch the live preview,
/// adjust the LED and the otoscope view, and capture stills.
///
/// - Important: Camera support in the SDK is under development. The callbacks and `setCameraMode` used here will change.
///
/// Preview frames arrive on the camera module's `frameReady` callback and captured stills on its
/// `recordedFrameReady` callback. The SDK calls both off the main actor, so each hops to the main actor to update
/// state. Stills are saved as PNG files in the app's Documents folder, under `camera-captures`.
@MainActor
final class CameraViewModel: ObservableObject {
    /// The selected camera mode. `.off` when there is no preview.
    @Published var cameraMode: CameraMode = .off
    /// `true` while a preview is starting or stopping. The controls are disabled meanwhile.
    @Published var isStarting = false
    /// The latest preview frame, or `nil` when there is no preview.
    @Published private(set) var previewImage: UIImage?
    /// Mode, state and the number of stills captured, for the status line.
    @Published var statusMessage = "Off : Ready [0 Captured]"
    /// Stills captured so far.
    @Published var capturedCount = 0
    /// The current white LED intensity.
    @Published var ledIntensity = 0
    /// The largest LED intensity the device accepts. The LED slider is shown only when this is above zero.
    @Published var ledIntensityMax = 0

    private let controller: MedWandController
    private var startTask: Task<Void, Never>?

    init(controller: MedWandController) {
        self.controller = controller
    }

    /// Stops the preview and any capture, and turns the camera off.
    func deactivate() {
        startTask?.cancel(); startTask = nil
        if cameraMode != .off {
            Task { try? await controller.stopSensor() }
        }
        cameraMode = .off
        previewImage = nil
        isStarting = false
        updateStatus("Ready")
    }

    /// Switches to `mode`, starting a preview, or stopping it for `.off`. Ignored while a start or stop is in progress.
    func selectMode(_ mode: CameraMode) {
        guard !isStarting else { return }
        if mode == .off {
            stopPreview()
        } else {
            startPreview(mode)
        }
    }

    /// Captures a still from the live preview. The image arrives later on the `recordedFrameReady` callback.
    func capture() {
        guard cameraMode != .off, previewImage != nil else { return }
        Task { await controller.startRecording() }
    }

    /// Sets the white LED intensity, limited to the device's maximum. The displayed value changes only if the device accepts it.
    func setLedIntensity(_ value: Int) {
        Task {
            let clamped = max(0, min(value, ledIntensityMax))
            if await controller.setCameraLedIntensity(clamped) {
                ledIntensity = clamped
            }
        }
    }

    // Present but currently inert — MedWandController's otoscope-radius
    // method is a stub one layer above a working implementation.
    func adjustRadius(_ increment: Int) {
        Task { await controller.cameraAdjustOtoscopeRadius(increment: increment) }
    }

    /// Moves the otoscope view left/right or up/down by the given increment. Otoscope mode only.
    func move(horizontal: Int? = nil, vertical: Int? = nil) {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraMove(incrementLeft: horizontal, incrementTop: vertical) }
    }

    /// Zooms the otoscope view by the given increment. Otoscope mode only.
    func zoom(_ increment: Int) {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraZoom(increment: increment) }
    }

    // Starts the preview for `mode`: installs the frame callbacks, then asks the SDK to switch to that mode.
    private func startPreview(_ mode: CameraMode) {
        isStarting = true
        cameraMode = mode
        previewImage = nil
        updateStatus("Starting")

        // The SDK calls the module's callbacks off the main actor, so each hops to the main actor to touch UI
        // state. (Camera support is under development; these callbacks and `setCameraMode` will change.)
        let onFrame: @Sendable (Data) -> Void = { [weak self] pngData in
            Task { @MainActor in self?.previewImage = UIImage(data: pngData) }
        }
        let onCapture: @Sendable (Data) -> Void = { [weak self] rawFrame in
            Task { @MainActor in await self?.handleCapturedFrame(rawFrame) }
        }

        startTask = Task {
            // Assign the callbacks before the preview starts: a frame raised while a callback is `nil` is
            // dropped.
            if let camera = await controller.camera {
                camera.frameReady = onFrame
                camera.recordedFrameReady = onCapture
            }

            let started = await controller.setCameraMode(mode, previewTarget: SimpleCameraPreviewTarget())
            guard started else {
                isStarting = false
                cameraMode = .off
                updateStatus("Error - \(await controller.cameraLastError ?? "Preview did not start")")
                return
            }

            ledIntensityMax = await controller.cameraLedIntensityMax
            ledIntensity = 0
            isStarting = false
            updateStatus("On")
        }
    }

    /// A still captured by `startRecording()`, as raw frame data; converted to PNG here.
    private func handleCapturedFrame(_ rawFrame: Data) async {
        guard let camera = await controller.camera, let png = await camera.pngFromFrame(rawFrame) else { return }
        saveCapture(png)
        capturedCount += 1
        updateStatus(cameraMode == .off ? "Ready" : "On")
    }

    // Stops the preview and turns the camera off.
    private func stopPreview() {
        isStarting = true
        updateStatus("Stopping")
        startTask?.cancel(); startTask = nil
        Task {
            try? await controller.stopSensor()
            isStarting = false
            cameraMode = .off
            previewImage = nil
            updateStatus("Ready")
        }
    }

    // Writes the still to `camera-captures` in the app's Documents folder, named by mode and time.
    private func saveCapture(_ png: Data) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let captureDir = dir.appendingPathComponent("camera-captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
        let url = captureDir.appendingPathComponent("\(cameraMode)-\(Date().timeIntervalSince1970).png")
        try? png.write(to: url)
    }

    private func updateStatus(_ state: String) {
        statusMessage = "\(cameraMode) : \(state) [\(capturedCount) Captured]"
    }
}
