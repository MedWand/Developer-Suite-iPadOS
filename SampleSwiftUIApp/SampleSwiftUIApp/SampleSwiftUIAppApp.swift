import SwiftUI

/// A minimal SwiftUI app that shows how to drive a MedWand with the MedWand SDK.
///
/// ## Structure
///
/// - ``AppViewModel`` is the composition root. It owns the `MedWandController`, installs the SDK's callbacks,
///   manages the connection, and tracks which workflow is selected.
/// - One view model per workflow holds that workflow's state and talks to the controller:
///   ``SimpleSensorViewModel`` (thermometer and pulse oximeter), ``StethoscopeViewModel``, ``CameraViewModel``
///   and ``EcgViewModel``.
/// - ``ContentView`` is the shell: startup notice, connecting screen, then toolbar, workflow and status bar.
///   Each workflow has its own view (``ThermometerView``, ``PulseOximeterView``, ``StethoscopeView``,
///   ``CameraView``, ``EcgView``) built on the shared chrome in ``WorkflowScaffold``.
/// - ``AndroidPalette`` holds the fixed colors every view uses.
///
/// ## Startup
///
/// ``AppViewModel/create()`` is `async` because `MWiPadOSSerialPortProvider` has an `async` initializer, and a
/// `MedWandController` cannot exist before it. The root scene therefore holds an optional view model and shows a
/// loading indicator until it resolves. This happens once per launch, not per connect/disconnect cycle.
@main
struct SampleSwiftUIAppApp: App {
    @State private var appViewModel: AppViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let appViewModel {
                    ContentView(appViewModel: appViewModel)
                } else {
                    ProgressView("Loading…")
                        .task {
                            appViewModel = await AppViewModel.create()
                        }
                }
            }
        }
    }
}
