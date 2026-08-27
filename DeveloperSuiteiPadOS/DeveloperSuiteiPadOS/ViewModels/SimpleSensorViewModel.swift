import Foundation
import MedWandSDK

/// Generic Idle/Busy/Disabled view model for a sensor whose entire workflow
/// is "start, stream readings, stop" — Thermometer and Pulse Oximeter.
/// Consolidates what Android implemented as three near-identical view models
/// (`Developer-Suite-Android/docs/DESIGN.md` §5.3 flags this as copy-paste,
/// not inheritance — the SDK's per-call `AsyncStream` return value removes
/// the need for it here).
@MainActor
final class SimpleSensorViewModel: ObservableObject {
    @Published var actionState: ActionState = .idle
    @Published var statusMessage = "Ready"
    @Published private(set) var lastReading: MedWandReading?

    private let start: () async throws -> AsyncStream<MedWandReading>
    private let stop: () async throws -> Void
    private var streamTask: Task<Void, Never>?

    init(
        start: @escaping () async throws -> AsyncStream<MedWandReading>,
        stop: @escaping () async throws -> Void
    ) {
        self.start = start
        self.stop = stop
    }

    var buttonTitle: String {
        actionState == .busy ? "Stop" : "Start"
    }

    func onActionButtonTapped() {
        switch actionState {
        case .idle: startSensor()
        case .busy: stopSensor()
        case .disabled: break
        }
    }

    /// Called when the workflow's view disappears / the app disconnects.
    func deactivate() {
        streamTask?.cancel()
        streamTask = nil
        if actionState == .busy {
            Task { try? await stop() }
        }
        actionState = .idle
        lastReading = nil
    }

    private func startSensor() {
        actionState = .disabled
        statusMessage = "Starting…"
        streamTask = Task {
            do {
                let stream = try await start()
                actionState = .busy
                statusMessage = "Reading"
                for await reading in stream {
                    lastReading = reading
                }
                // Stream ended (device stopped it, error, or disconnect).
                if actionState == .busy {
                    actionState = .idle
                    statusMessage = "Ready"
                }
            } catch {
                actionState = .idle
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func stopSensor() {
        actionState = .disabled
        streamTask?.cancel()
        streamTask = nil
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
