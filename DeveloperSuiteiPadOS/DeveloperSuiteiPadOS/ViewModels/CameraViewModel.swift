import Foundation
import UIKit
import MedWandSDK

/// `CameraPreviewTarget` is an empty marker protocol with no accessible
/// initializer of its own — a concrete conformer is required to instantiate it.
private struct SimpleCameraPreviewTarget: CameraPreviewTarget {}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var cameraMode: CameraMode = .off
    @Published var isStarting = false
    @Published private(set) var previewImage: UIImage?
    @Published var statusMessage = "Off : Ready [0 Captured]"
    @Published var capturedCount = 0
    @Published var ledIntensity = 0
    @Published var ledIntensityMax = 0

    private let controller: MedWandController
    private var frameTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?

    init(controller: MedWandController) {
        self.controller = controller
    }

    func deactivate() {
        frameTask?.cancel(); frameTask = nil
        captureTask?.cancel(); captureTask = nil
        if cameraMode != .off {
            Task { try? await controller.stopSensor() }
        }
        cameraMode = .off
        previewImage = nil
        isStarting = false
        updateStatus("Ready")
    }

    func selectMode(_ mode: CameraMode) {
        guard !isStarting else { return }
        if mode == .off {
            stopPreview()
        } else {
            startPreview(mode)
        }
    }

    func capture() {
        guard cameraMode != .off, previewImage != nil else { return }
        Task { await controller.camera?.recordFrame() }
    }

    func setLedIntensity(_ value: Int) {
        Task {
            let clamped = max(0, min(value, ledIntensityMax))
            if await controller.setCameraLedIntensity(clamped) {
                ledIntensity = clamped
            }
        }
    }

    // Present but currently inert — MedWandController's otoscope-radius
    // method is a stub one layer above a working implementation. See
    // docs/DESIGN.md's known-gaps section.
    func adjustRadius(_ increment: Int) {
        Task { await controller.cameraAdjustOtoscopeRadius(increment: increment) }
    }

    func move(horizontal: Int? = nil, vertical: Int? = nil) {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraMove(incrementLeft: horizontal, incrementTop: vertical) }
    }

    func zoom(_ increment: Int) {
        guard cameraMode == .otoscope else { return }
        Task { await controller.cameraZoom(increment: increment) }
    }

    private func startPreview(_ mode: CameraMode) {
        isStarting = true
        cameraMode = mode
        previewImage = nil
        updateStatus("Starting")

        frameTask = Task {
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

            guard let camera = await controller.camera else { return }
            for await pngData in await camera.frameStream {
                previewImage = UIImage(data: pngData)
            }
        }

        captureTask = Task {
            guard let camera = await controller.camera else { return }
            for await rawFrame in await camera.recordedFrameStream {
                guard let png = await camera.pngFromFrame(rawFrame) else { continue }
                saveCapture(png)
                capturedCount += 1
                updateStatus(cameraMode == .off ? "Ready" : "On")
            }
        }
    }

    private func stopPreview() {
        isStarting = true
        updateStatus("Stopping")
        frameTask?.cancel(); frameTask = nil
        captureTask?.cancel(); captureTask = nil
        Task {
            try? await controller.stopSensor()
            isStarting = false
            cameraMode = .off
            previewImage = nil
            updateStatus("Ready")
        }
    }

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
