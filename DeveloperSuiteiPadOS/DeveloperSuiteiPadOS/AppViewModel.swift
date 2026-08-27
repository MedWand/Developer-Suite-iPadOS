import Foundation
import CoreGraphics
import MedWandSDK

/// Composition root — owns the `MedWandController`, connection lifecycle,
/// and which workflow is currently selected. Replaces Android's `MainWindow`
/// (`Developer-Suite-Android/docs/DESIGN.md` §5.1). Unlike `MainWindow`,
/// this does not manually route per-sensor readings to "whichever view is
/// active" — each workflow's own view model consumes its own `AsyncStream`
/// directly (see `docs/DESIGN.md` §2's "biggest structural deviation").
///
/// `MWiPadOSSerialPortProvider()` has an `async` initializer, so a working
/// `MedWandController` can't exist until that's awaited — `create()` is the
/// only way to obtain an `AppViewModel`; there is no synchronous `init()`.
/// The app's root view shows a brief loading state while this runs (see
/// `DeveloperSuiteiPadOSApp.swift`).
@MainActor
final class AppViewModel: ObservableObject {
    let controller: MedWandController

    @Published var startupNoticeAccepted = false
    @Published var selectedWorkflow: Workflow?
    @Published var deviceState: MedWandDeviceState = .notConnected
    @Published var statusMessage = "Starting…"
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published private(set) var ecgFrameImage: CGImage?

    @Published var toolbarEnabled: [Workflow: Bool] = [
        .thermometer: false, .pulseOximeter: false, .stethoscope: false,
        .camera: false, .ecg: false,
    ]

    let thermometerViewModel: SimpleSensorViewModel
    let pulseOximeterViewModel: SimpleSensorViewModel
    let stethoscopeViewModel: StethoscopeViewModel
    let cameraViewModel: CameraViewModel
    let ecgViewModel: EcgViewModel

    private var ecgRenderTarget: ECGRenderTargetImpl?
    private var deviceStateTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var ledTask: Task<Void, Never>?

    // Assigned in the init body, not as `lazy var` initializers: a `lazy
    // var`'s initializer expression on a `@MainActor` type that captures an
    // actor (non-MainActor) value in a closure trips a Swift 6 isolation
    // diagnostic ("default argument cannot be both main actor-isolated and
    // actor-isolated") — a quirk of how lazy-property initializers are
    // isolation-checked, not a real data race.
    private init(controller: MedWandController) {
        self.controller = controller
        thermometerViewModel = SimpleSensorViewModel(
            start: { try await controller.startThermometer() },
            stop: { try await controller.stopThermometer() }
        )
        pulseOximeterViewModel = SimpleSensorViewModel(
            start: { try await controller.startPulseOximeter() },
            stop: { try await controller.stopPulseOximeter() }
        )
        stethoscopeViewModel = StethoscopeViewModel(controller: controller)
        cameraViewModel = CameraViewModel(controller: controller)
        ecgViewModel = EcgViewModel(controller: controller)
    }

    static func create() async -> AppViewModel {
        let provider = await MWiPadOSSerialPortProvider()
        let controller = MedWandController(serialPortProvider: provider)
        return AppViewModel(controller: controller)
    }

    /// Runs once, after the BETA notice is accepted.
    func connectAndInitialize() async {
        startDeviceStreams()

        await controller.construct(license: mwSDKLicense, publicKey: mwSDKPublicKey)
        guard await controller.isLicenseValid else {
            connectionError = "No valid license."
            return
        }

        statusMessage = "Connecting to MedWand…"
        await controller.connect()
        guard await controller.isConnected else {
            connectionError = "MedWand not found. Please connect your MedWand and try again."
            return
        }

        statusMessage = "Initializing MedWand…"
        await controller.initialize()
        guard await controller.isInitialized else {
            connectionError = "MedWand did not initialize."
            return
        }

        // render(_:) is `nonisolated` per the ECGRenderTarget protocol, called
        // from ECGModule's own actor-isolated render task (an ordinary async
        // context — not a raw C callback, so a Task hop here is the normal,
        // safe case, unlike the IOKit-callback pathology documented in the
        // SDK's own design doc appendix on the CDCDriverInterface migration).
        let renderTarget = ECGRenderTargetImpl { [weak self] image in
            Task { @MainActor in
                self?.ecgFrameImage = image.cgImage
            }
        }
        ecgRenderTarget = renderTarget
        await controller.configure(ecgRenderer: renderTarget)

        isConnected = true
        let canUseCamera = await controller.canUseCamera
        let hasValidOtoscope = await controller.hasValidOtoscope
        toolbarEnabled = [
            .thermometer: true,
            .pulseOximeter: true,
            .stethoscope: await controller.hasValidStethoscope,
            .camera: canUseCamera && hasValidOtoscope,
            .ecg: await controller.hasValidECG,
        ]
        statusMessage = "Connected"
    }

    /// Recast from Android's process-killing "Exit" — see
    /// `docs/DESIGN.md`'s per-workflow mapping table for why.
    func disconnect() async {
        selectedWorkflow = nil
        thermometerViewModel.deactivate()
        pulseOximeterViewModel.deactivate()
        stethoscopeViewModel.deactivate()
        cameraViewModel.deactivate()
        ecgViewModel.deactivate()

        try? await controller.stopSensor()
        await controller.disconnect()
        await controller.shutdown()

        isConnected = false
        toolbarEnabled = toolbarEnabled.mapValues { _ in false }
        statusMessage = "Disconnected"
    }

    func selectWorkflow(_ workflow: Workflow?) {
        deactivateCurrentWorkflow()
        selectedWorkflow = workflow
        activateWorkflow(workflow)
    }

    private func activateWorkflow(_ workflow: Workflow?) {
        switch workflow {
        case .stethoscope: stethoscopeViewModel.activate()
        case .camera: break // CameraViewModel activates lazily on mode selection
        case .ecg: ecgViewModel.activate()
        case .thermometer, .pulseOximeter, nil: break
        }
    }

    private func deactivateCurrentWorkflow() {
        switch selectedWorkflow {
        case .thermometer: thermometerViewModel.deactivate()
        case .pulseOximeter: pulseOximeterViewModel.deactivate()
        case .stethoscope: stethoscopeViewModel.deactivate()
        case .camera: cameraViewModel.deactivate()
        case .ecg: ecgViewModel.deactivate()
        case nil: break
        }
    }

    private func startDeviceStreams() {
        deviceStateTask = Task {
            for await state in await controller.deviceStateStream {
                deviceState = state
            }
        }
        errorTask = Task {
            for await error in await controller.errorStream {
                connectionError = error.message.isEmpty ? "\(error.code)" : error.message
            }
        }
        ledTask = Task {
            for await intensity in await controller.ledIntensityStream {
                cameraViewModel.ledIntensity = intensity
            }
        }
    }
}
