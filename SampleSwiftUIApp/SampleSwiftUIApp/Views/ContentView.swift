import SwiftUI

/// The app's shell. It shows one of three screens, depending on the state of ``AppViewModel``:
///
/// 1. ``StartupNoticeView``, until the user accepts the BETA notice. Accepting it starts the connection.
/// 2. A connecting screen, until the MedWand is connected and initialized. It shows progress, or the error and a
///    Retry button.
/// 3. The main screen: a toolbar on top, the selected workflow in the middle, and a status bar at the bottom.
///
/// Workflows are activated and deactivated by ``AppViewModel/selectWorkflow(_:)``. The workflow views that hold
/// hardware (stethoscope, camera and ECG) also use `.onDisappear`, so they release it whenever SwiftUI removes
/// them. Moving the app to the background disconnects from the MedWand.
struct ContentView: View {
    @ObservedObject var appViewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !appViewModel.startupNoticeAccepted {
                StartupNoticeView {
                    appViewModel.startupNoticeAccepted = true
                    Task { await appViewModel.connectAndInitialize() }
                }
            } else if !appViewModel.isConnected {
                connectingView
            } else {
                mainView
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && appViewModel.isConnected {
                Task { await appViewModel.disconnect() }
            }
        }
    }

    /// Shown from the moment the notice is accepted until the MedWand is ready. It shows a progress indicator while
    /// connecting. If connecting fails, it shows the error and a Retry button that runs ``AppViewModel/connectAndInitialize()`` again.
    private var connectingView: some View {
        VStack(spacing: 16) {
            if appViewModel.connectionError == nil {
                ProgressView()
            }
            Text(appViewModel.statusMessage)
            if let error = appViewModel.connectionError {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button("Retry") {
                    appViewModel.connectionError = nil
                    Task { await appViewModel.connectAndInitialize() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AndroidPalette.controlDark)
    }

    /// The main screen once the MedWand is connected.
    private var mainView: some View {
        VStack(spacing: 0) {
            toolbar
            workflowContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            statusBar
        }
        .background(AndroidPalette.controlDark)
    }

    /// The top bar: the logo, one icon button per ``Workflow``, a divider, and Exit on the right.
    ///
    /// A workflow's button is dimmed and disabled when the connected MedWand or the license cannot use it. Exit
    /// disconnects from the MedWand.
    private var toolbar: some View {
        HStack(spacing: 0) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 311, height: 119)

            ForEach(Workflow.allCases) { workflow in
                toolbarButton(
                    iconName: workflow.toolbarIconName,
                    enabled: appViewModel.toolbarEnabled[workflow] ?? false
                ) {
                    appViewModel.selectWorkflow(workflow)
                }
            }

            Rectangle()
                .fill(Color.gray)
                .frame(width: 1)
                .padding(.leading, 15)

            Spacer()

            toolbarButton(iconName: "exit_off", enabled: appViewModel.isConnected) {
                Task { await appViewModel.disconnect() }
            }
        }
        .frame(height: 122)
        .background(AndroidPalette.control)
    }

    /// An icon-only button, drawn at 35% opacity and disabled when `enabled` is `false`.
    private func toolbarButton(iconName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 144, height: 119)
                .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
    }

    @ViewBuilder
    /// The view for the selected workflow, or the placeholder when none is selected.
    private var workflowContent: some View {
        switch appViewModel.selectedWorkflow {
        case .thermometer:
            ThermometerView(viewModel: appViewModel.thermometerViewModel)
        case .pulseOximeter:
            PulseOximeterView(viewModel: appViewModel.pulseOximeterViewModel)
        case .stethoscope:
            StethoscopeView(viewModel: appViewModel.stethoscopeViewModel)
        case .camera:
            CameraView(viewModel: appViewModel.cameraViewModel)
        case .ecg:
            EcgView(appViewModel: appViewModel, viewModel: appViewModel.ecgViewModel)
        case nil:
            placeholderView
        }
    }

    // Shown in the content area before any workflow is selected.
    private var placeholderView: some View {
        Text("Select a workflow above")
            .font(.system(size: 24))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(15)
            .background(AndroidPalette.actionButtonDisabled)
    }

    /// A single line at the bottom of the main screen: the connection error, in red, if there is one; otherwise the
    /// status message.
    private var statusBar: some View {
        HStack {
            Text(appViewModel.connectionError ?? appViewModel.statusMessage)
                .foregroundStyle(appViewModel.connectionError == nil ? AndroidPalette.control : .red)
            Spacer()
        }
        .font(.system(size: 16))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(AndroidPalette.controlDarkDark)
    }
}
