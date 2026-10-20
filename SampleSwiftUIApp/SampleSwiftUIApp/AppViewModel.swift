import Foundation
import CoreGraphics
import QuartzCore
import MedWandSDK

/// The composition root: owns the `MedWandController`, the connection lifecycle, and the selected workflow.
///
/// Create it with ``create()``. There is no synchronous initializer, because `MWiPadOSSerialPortProvider()` has an
/// `async` initializer and a `MedWandController` cannot exist until it is awaited. The root view shows a loading
/// indicator while that runs (see ``SampleSwiftUIAppApp``).
///
/// ## Responsibilities
///
/// - **Connection.** ``connectAndInitialize()`` runs the SDK's startup sequence (`construct`, `connect`,
///   `initialize`, `configure`) and enables only the toolbar workflows that the license and the attached MedWand
///   support. ``disconnect()`` ends the session. `handleDeviceLost()` handles an unplug.
/// - **SDK callbacks.** `installCallbacks()` assigns each of the controller's callbacks once and passes what they
///   deliver to the right view model (see below).
/// - **Workflow switching.** ``selectWorkflow(_:)`` deactivates the current workflow's view model and activates the
///   new one.
///
/// ## Data flow
///
/// ```
/// MedWand → SDK → controller callback → private AsyncStream → one main-actor task → view model → view
/// ```
///
/// The SDK delivers every sensor's readings through the single `onReadingReceived` callback, and `route(_:)` sends
/// each reading to the view model for its `sensorType`. ECG readings need no routing: the SDK draws the waveform
/// into ``ecgDisplayLayer`` itself.
@MainActor
final class AppViewModel: ObservableObject {
    /// The SDK controller that every workflow talks to.
    let controller: MedWandController

    /// `true` once the user has accepted the BETA notice. The app connects only after that.
    @Published var startupNoticeAccepted = false
    /// The workflow shown in the content area, or `nil` for the placeholder.
    @Published var selectedWorkflow: Workflow?
    /// The latest value from the controller's `onDeviceStateChanged` callback.
    @Published var deviceState: MedWandDeviceState = .notConnected
    /// Text for the status bar and the connecting screen.
    @Published var statusMessage = "Starting…"
    /// `true` after a complete connect and initialize; `false` again after ``disconnect()`` or an unplug.
    @Published var isConnected = false
    /// A user-visible error, shown in red in the status bar, and with a Retry button on the connecting screen.
    @Published var connectionError: String?

    /// Which workflows the toolbar lets the user select. Set at the end of ``connectAndInitialize()``.
    @Published var toolbarEnabled: [Workflow: Bool] = [
        .thermometer: false, .pulseOximeter: false, .stethoscope: false,
        .camera: false, .ecg: false,
    ]

    // One view model per workflow. The thermometer and the pulse oximeter share `SimpleSensorViewModel` because
    // both are just "start, receive readings, stop".
    let thermometerViewModel: SimpleSensorViewModel
    let pulseOximeterViewModel: SimpleSensorViewModel
    let stethoscopeViewModel: StethoscopeViewModel
    let cameraViewModel: CameraViewModel
    let ecgViewModel: EcgViewModel

    /// The layer the SDK paints the live ECG waveform into.
    ///
    /// Created once and handed to the SDK in ``connectAndInitialize()`` through `configure(ecgLayer:)`.
    /// ``ECGWaveformView`` only attaches and detaches it as a sublayer; it never creates or destroys it, because
    /// the layer lives as long as the app, not as long as any one view.
    let ecgDisplayLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.actions = ["contents": NSNull()]
        return layer
    }()
    // One main-actor task per SDK callback; see `installCallbacks()`.
    private var callbackTasks: [Task<Void, Never>] = []

    // Set when the user exits or the app backgrounds, so the `.notConnected` that an intentional
    // `disconnect()` produces is not mistaken for the MedWand being unplugged. Never reset: that
    // path ends in `shutdown()`.
    private var isShuttingDown = false

    // Assigned in the init body, not as `lazy var` initializers: a `lazy
    // var`'s initializer expression on a `@MainActor` type that captures an
    // actor (non-MainActor) value in a closure trips a Swift 6 isolation
    // diagnostic ("default argument cannot be both main actor-isolated and
    // actor-isolated") — a quirk of how lazy-property initializers are
    // isolation-checked, not a real data race.
    private init(controller: MedWandController) {
        self.controller = controller
        thermometerViewModel = SimpleSensorViewModel(
            start: { await controller.startThermometer() },
            stop: { try await controller.stopSensor() }
        )
        pulseOximeterViewModel = SimpleSensorViewModel(
            start: { await controller.startPulseOximeter() },
            stop: { try await controller.stopSensor() }
        )
        stethoscopeViewModel = StethoscopeViewModel(controller: controller)
        cameraViewModel = CameraViewModel(controller: controller)
        ecgViewModel = EcgViewModel(controller: controller)
    }

    /// Creates the serial port provider (an `async` step) and a controller that uses it, and returns the view model.
    static func create() async -> AppViewModel {
        let provider = await MWiPadOSSerialPortProvider()
        let controller = MedWandController(serialPortProvider: provider)
        return AppViewModel(controller: controller)
    }

    /// Connects to the MedWand and prepares it for use. Called after the BETA notice is accepted, and again by Retry.
    ///
    /// The steps are: install the callbacks, `construct` (which checks the license), `connect`, `initialize`, and
    /// `configure`. Each step is checked. If one fails, ``connectionError`` is set and the sequence stops, which
    /// leaves the Retry button on screen.
    func connectAndInitialize() async {
        installCallbacks()

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

        // Give the SDK the ECG display layer. It paints each composited ECG frame into the layer itself,
        // making its own main-actor hop, so the app needs no callback or Task for the waveform.
        await controller.configure(ecgLayer: ECGLayerHandle(layer: ecgDisplayLayer))
        await stethoscopeViewModel.installRecordingCallback()

        isConnected = true
        let canUseCamera = await controller.canUseCamera
        let hasValidOtoscope = await controller.hasValidOtoscope
        toolbarEnabled = [
            .thermometer: true,
            .pulseOximeter: true,
            .stethoscope: await controller.hasValidStethoscope,
            .camera: canUseCamera && hasValidOtoscope,
            .ecg: await controller.hasValidEcg,
        ]
        statusMessage = "Connected"
    }

    /// Ends the session: stops any active sensor, disconnects, and shuts the controller down.
    ///
    /// Used by the toolbar's Exit button and when the app moves to the background. The SDK's `shutdown()` clears
    /// its callbacks, and the UI returns to the connecting screen with the status "Disconnected".
    func disconnect() async {
        isShuttingDown = true
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

    /// The MedWand was unplugged while connected. The SDK has already stopped any active sensor and
    /// finished its reading stream; this resets the UI and shows the connecting screen, whose Retry
    /// button runs `connectAndInitialize()` again. Reconnection is manual: the SDK emits no event
    /// when the device comes back.
    private func handleDeviceLost() {
        deactivateCurrentWorkflow()
        thermometerViewModel.deactivate()
        pulseOximeterViewModel.deactivate()
        stethoscopeViewModel.deactivate()
        cameraViewModel.deactivate()
        ecgViewModel.deactivate()

        selectedWorkflow = nil
        isConnected = false
        toolbarEnabled = toolbarEnabled.mapValues { _ in false }
        statusMessage = "MedWand disconnected."
        connectionError = "MedWand disconnected. Plug it back in and tap Retry."
    }

    /// Shows `workflow` (or the placeholder, for `nil`), deactivating the previous workflow first.
    func selectWorkflow(_ workflow: Workflow?) {
        deactivateCurrentWorkflow()
        selectedWorkflow = workflow
        activateWorkflow(workflow)
    }

    // Starts the view model of the workflow being shown, if it has anything to start.
    private func activateWorkflow(_ workflow: Workflow?) {
        switch workflow {
        case .stethoscope: stethoscopeViewModel.activate()
        case .camera: break // CameraViewModel activates lazily on mode selection
        case .ecg: ecgViewModel.activate()
        case .thermometer, .pulseOximeter, nil: break
        }
    }

    // Stops the view model of the workflow being left.
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

    /// Assigns the SDK's callbacks, once for the controller's lifetime (Retry calls `connectAndInitialize()`
    /// again, which finds them already installed). This must happen before `construct`/`connect`: an event
    /// raised while a callback is `nil` is dropped, with no replay.
    ///
    /// The SDK calls each callback off the main actor, in order, one value at a time. Each callback only
    /// yields into a stream this class owns, and one main-actor task reads that stream — which keeps the
    /// order (a `Task { @MainActor in … }` per event would not) and puts the handling on the main actor.
    /// The streams are private to this class, so nothing else reads them.
    private func installCallbacks() {
        guard callbackTasks.isEmpty else { return }

        let (states, statesOut) = AsyncStream.makeStream(of: MedWandDeviceState.self)
        let (errors, errorsOut) = AsyncStream.makeStream(of: MedWandDeviceError.self)
        let (readingStates, readingStatesOut) = AsyncStream.makeStream(of: MedWandReadingState.self)
        let (readings, readingsOut) = AsyncStream.makeStream(of: MedWandReading.self)
        let (intensities, intensitiesOut) = AsyncStream.makeStream(of: Int.self)

        controller.onDeviceStateChanged = { statesOut.yield($0) }
        controller.onDeviceError = { errorsOut.yield($0) }
        controller.onReadingStateChanged = { readingStatesOut.yield($0) }
        controller.onReadingReceived = { readingsOut.yield($0) }
        controller.onLedIntensityChanged = { intensitiesOut.yield($0) }

        callbackTasks = [
            Task {
                for await state in states {
                    deviceState = state
                    // `isConnected` is only true after a full connect + initialize, so the
                    // `.notConnected` events emitted while connecting are ignored.
                    if state == .notConnected, isConnected, !isShuttingDown {
                        handleDeviceLost()
                    }
                }
            },
            Task {
                for await error in errors {
                    connectionError = error.message.isEmpty ? "\(error.code)" : error.message
                }
            },
            Task {
                // A sensor session ends without a reading: the user stopped it, the MedWand was unplugged,
                // or an error occurred. The simple-sensor view models return to Ready.
                for await state in readingStates where state == .stopped || state == .error {
                    thermometerViewModel.sessionEnded()
                    pulseOximeterViewModel.sessionEnded()
                }
            },
            Task {
                for await reading in readings {
                    route(reading)
                }
            },
            Task {
                for await intensity in intensities {
                    cameraViewModel.ledIntensity = intensity
                }
            },
        ]
    }

    /// The SDK delivers every sensor's readings through `onReadingReceived`; `sensorType` says whose they are.
    /// ECG readings need no handling here: the SDK draws them into `ecgDisplayLayer` itself.
    private func route(_ reading: MedWandReading) {
        switch reading.sensorType {
        case "Thermometer": thermometerViewModel.receive(reading)
        case "PulseOximeter": pulseOximeterViewModel.receive(reading)
        default: break
        }
    }
}
