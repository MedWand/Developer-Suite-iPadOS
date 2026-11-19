import AVFoundation
import Foundation
import UIKit
import MedWandSDK

/// View model for the camera workflow: choose a mode (off, dermatoscope or otoscope), watch the live preview,
/// adjust the LED and the otoscope view, and capture stills.
///
/// The SDK draws the live preview into ``previewLayer``, which `CameraView` shows (Windows' `Image` preview target is a
/// `CameraLayerHandle` here). Captured stills arrive on the camera module's `recordedFrameReady` callback, which the SDK
/// calls off the main actor, so it hops to the main actor to update state. The SDK turns a frame into a `CGImage`; this
/// app encodes it as PNG and saves it in the app's Documents folder, under `camera-captures`. The SDK never asks for camera permission, so this view model does before
/// it starts a preview.
@MainActor
final class CameraViewModel: ObservableObject {
    /// The selected camera mode. `.off` when there is no preview.
    @Published var cameraMode: CameraMode = .off
    /// `true` while a preview is starting or stopping. The controls are disabled meanwhile.
    @Published var isStarting = false
    /// `true` while the camera is being turned off (also `isStarting`), so the preview area says so instead of "Starting".
    @Published var isStopping = false
    /// The layer the SDK draws the live preview into. `CameraView` hosts it.
    let previewLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.backgroundColor = UIColor.black.cgColor
        return layer
    }()
    /// Mode, state and the number of stills captured, for the status line.
    @Published var statusMessage = "Off : Ready [0 Captured]"
    /// Stills captured so far.
    @Published var capturedCount = 0
    /// The white LED intensity the device last reported. The slider does not show this while the finger is on it; see
    /// ``ledSliderValue``.
    @Published var ledIntensity = 0 {
        didSet {
            if !isAdjustingLed, ledSendTask == nil { Task { await syncLedSlider() } }
        }
    }
    /// What the LED slider and its label show. The finger sets it at once, without waiting for the device (each value is a
    /// serial round trip); it follows the device only when the finger is up and nothing is waiting to be sent.
    @Published var ledSliderValue = 0.0
    /// The largest LED intensity the device accepts. The LED control is shown only when this is above zero, which is only
    /// while a camera mode is on: it is set when a preview has started, and set back to zero when it ends.
    @Published var ledIntensityMax = 0
    /// `true` if the camera's LED has intensity levels (the S2 and S3, shown as a slider); `false` if it is only on or off
    /// (the S4, shown as a button; see ``toggleLed()``).
    @Published var ledAdjustable = true

    private let controller: MedWandController
    private var startTask: Task<Void, Never>?
    // `true` while the finger is on the LED slider.
    private var isAdjustingLed = false
    // The newest value the slider asked for and the device has not been sent yet; older ones are skipped.
    private var pendingLedIntensity: Int?
    // The task that sends LED values, one command at a time. `nil` when nothing is being sent.
    private var ledSendTask: Task<Void, Never>?

    init(controller: MedWandController) {
        self.controller = controller
    }

    /// Stops the preview and any capture, and turns the camera off.
    func deactivate() {
        startTask?.cancel(); startTask = nil
        pendingLedIntensity = nil
        hideLedControl()
        if cameraMode != .off {
            Task { try? await controller.stopSensor() }
        }
        cameraMode = .off
        previewLayer.contents = nil
        isStarting = false
        isStopping = false
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
        guard cameraMode != .off, !isStarting else { return }
        Task { await controller.startRecording() }
    }

    /// Turns the LED of a camera that is only on or off on or off: the maximum when it is off, zero when it is on. It goes
    /// the same way as the slider, so the label follows at once and the device is sent the newest value.
    func toggleLed() {
        ledSliderChanged(ledSliderValue > 0 ? 0 : ledIntensityMax)
    }

    /// The LED slider moved to `value`. The slider shows it at once and the device is sent the newest value as fast as
    /// it answers.
    func ledSliderChanged(_ value: Int) {
        ledSliderValue = Double(value)
        setLedIntensity(value)
    }

    /// The finger touched (`true`) or left (`false`) the LED slider.
    func ledEditingChanged(_ editing: Bool) {
        isAdjustingLed = editing
        if !editing { Task { await syncLedSlider() } }
    }

    /// Sets the white LED intensity, limited to the device's maximum.
    ///
    /// Values arrive faster than the device answers (every value is a serial command and a wait for its reply), so this keeps
    /// only the newest one: at most one command is in flight, and the values in between are skipped. When the last one has been
    /// sent the slider is set to what the device really has, so a value the device refused does not stay on screen.
    func setLedIntensity(_ value: Int) {
        pendingLedIntensity = max(0, min(value, ledIntensityMax))
        guard ledSendTask == nil else { return }
        ledSendTask = Task {
            while let next = pendingLedIntensity {
                pendingLedIntensity = nil
                _ = await controller.setCameraLedIntensity(next)
            }
            ledSendTask = nil
            await syncLedSlider()
        }
    }

    // Sets the slider to the device's real intensity, unless the finger is on it or a value is still being sent. It reads the
    // controller, not `ledIntensity`, which arrives through a stream and can be older.
    private func syncLedSlider() async {
        guard !isAdjustingLed, ledSendTask == nil else { return }
        let actual = await controller.ledIntensity
        guard !isAdjustingLed, ledSendTask == nil else { return }
        ledSliderValue = Double(actual)
    }

    /// Enlarges (positive) or shrinks (negative) the circular otoscope aperture. Otoscope mode only.
    func adjustRadius(_ increment: Int) {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraRadius(increment: increment) }
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

    /// Restores the otoscope view's zoom, circle size and position to the camera's defaults. Otoscope mode only.
    func reset() {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraReset() }
    }

    // Starts the preview for `mode`: asks for camera permission, installs the capture callback, then asks the SDK to
    // switch to that mode, drawing into `previewLayer`.
    private func startPreview(_ mode: CameraMode) {
        isStarting = true
        hideLedControl()
        cameraMode = mode
        previewLayer.contents = nil
        updateStatus("Starting")

        // The SDK calls the module's callback off the main actor, so it hops to the main actor to touch UI state.
        let onCapture: @Sendable (Data) -> Void = { [weak self] rawFrame in
            Task { @MainActor in await self?.handleCapturedFrame(rawFrame) }
        }

        startTask = Task {
            // The SDK never asks for camera permission.
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }

            // Assign the callback before the preview starts: a frame raised while a callback is `nil` is dropped.
            if let camera = await controller.camera {
                camera.recordedFrameReady = onCapture
            }

            let started: Bool
            do {
                started = try await controller.setCameraMode(mode, previewTarget: CameraLayerHandle(layer: previewLayer))
            } catch {
                started = false
            }
            guard started else {
                isStarting = false
                hideLedControl()
                cameraMode = .off
                updateStatus("Error - \(await controller.cameraLastError ?? "Preview did not start")")
                return
            }

            ledAdjustable = await controller.cameraLedIntensityAdjustable
            ledIntensityMax = await controller.cameraLedIntensityMax
            ledIntensity = await controller.ledIntensity
            ledSliderValue = Double(ledIntensity)
            isStarting = false
            updateStatus("On")
        }
    }

    /// A still captured by `startRecording()`, as raw frame data; the SDK makes an image of it and the PNG is encoded here.
    private func handleCapturedFrame(_ rawFrame: Data) async {
        guard let image = await controller.cameraImageFromFrame(bytes: rawFrame),
              let png = UIImage(cgImage: image).pngData() else { return }
        saveCapture(png)
        capturedCount += 1
        updateStatus(cameraMode == .off ? "Ready" : "On")
    }

    // Stops the preview and turns the camera off.
    private func stopPreview() {
        isStarting = true
        isStopping = true
        hideLedControl()
        updateStatus("Stopping")
        startTask?.cancel(); startTask = nil
        Task {
            try? await controller.stopSensor()
            isStarting = false
            isStopping = false
            cameraMode = .off
            previewLayer.contents = nil
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

    // Hides the LED control: there is no LED to set while no preview runs.
    private func hideLedControl() {
        ledIntensityMax = 0
        ledAdjustable = true
    }

    private func updateStatus(_ state: String) {
        statusMessage = "\(cameraMode) : \(state) [\(capturedCount) Captured]"
    }
}
