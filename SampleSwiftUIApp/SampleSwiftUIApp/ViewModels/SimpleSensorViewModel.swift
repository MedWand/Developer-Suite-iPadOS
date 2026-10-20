import Foundation
import MedWandSDK

/// View model for a sensor whose whole workflow is "start, receive readings, stop": the thermometer and the
/// pulse oximeter.
///
/// One class serves both, because they differ only in the two closures they are created with (how to start and
/// how to stop the sensor). ``AppViewModel`` creates one instance per sensor and calls ``receive(_:)`` with the
/// readings that belong to it, because the SDK delivers every sensor's readings through a single
/// `onReadingReceived` callback.
///
/// The action button follows ``ActionState``: idle, then disabled while starting, busy while reading, disabled
/// while stopping, and idle again.
@MainActor
final class SimpleSensorViewModel: ObservableObject {
    /// Drives the Start/Stop button.
    @Published var actionState: ActionState = .idle
    /// Text for the status line under the reading.
    @Published var statusMessage = "Ready"
    /// The most recent reading for this sensor. `nil` until one arrives, and again after the session ends.
    @Published private(set) var lastReading: MedWandReading?

    // How to start and stop this sensor. Supplied by `AppViewModel`.
    private let start: () async -> Bool
    private let stop: () async throws -> Void

    init(
        start: @escaping () async -> Bool,
        stop: @escaping () async throws -> Void
    ) {
        self.start = start
        self.stop = stop
    }

    /// The text of the action button.
    var buttonTitle: String {
        actionState == .busy ? "Stop" : "Start"
    }

    /// Starts the sensor when idle, stops it when busy, and ignores taps while a start or stop is in progress.
    func onActionButtonTapped() {
        switch actionState {
        case .idle: startSensor()
        case .busy: stopSensor()
        case .disabled: break
        }
    }

    /// Stops the sensor if it is running and clears the display. Called when the workflow is left or the app
    /// disconnects.
    func deactivate() {
        if actionState == .busy {
            Task { try? await stop() }
        }
        actionState = .idle
        lastReading = nil
    }

    /// A reading for this sensor, routed here by `AppViewModel`.
    func receive(_ reading: MedWandReading) {
        guard actionState == .busy else { return }
        lastReading = reading
    }

    /// The SDK's reading session ended without this view model asking for it: the MedWand was unplugged, or
    /// an error occurred. Does nothing unless this sensor was running.
    func sessionEnded() {
        guard actionState == .busy else { return }
        actionState = .idle
        statusMessage = "Ready"
    }

    private func startSensor() {
        actionState = .disabled
        statusMessage = "Starting…"
        Task {
            // `start` returns `false` when the sensor did not start. The reason is reported to the SDK's
            // `onLicenseError` / `onDeviceError` callbacks, and `AppViewModel` shows device errors.
            if await start() {
                actionState = .busy
                statusMessage = "Reading"
            } else {
                actionState = .idle
                statusMessage = "Could not start. Check the license and the MedWand connection."
            }
        }
    }

    private func stopSensor() {
        actionState = .disabled
        Task {
            do {
                try await stop()
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            actionState = .idle
            statusMessage = "Ready"
        }
    }
}
