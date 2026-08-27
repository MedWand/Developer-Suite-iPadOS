import SwiftUI

/// Toolbar + status bar + workflow host — replaces Android's `MainWindow`
/// shell (`Developer-Suite-Android/docs/DESIGN.md` §5.1). Workflow
/// activation/deactivation happens through `AppViewModel.selectWorkflow`,
/// not per-view `.onAppear`, except where a workflow view also needs its own
/// `.onAppear`/`.onDisappear` for symmetry with SwiftUI's own lifecycle
/// (Stethoscope, ECG) — see docs/DESIGN.md's concurrency section.
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

    private var mainView: some View {
        VStack(spacing: 0) {
            toolbar
            workflowContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            statusBar
        }
        .background(AndroidPalette.controlDark)
    }

    /// Matches Android's `ToolBar` composable (`MainActivity.kt`) icon-for-
    /// icon: logo, one icon-only button per workflow (no text label, 35%
    /// alpha when disabled), a divider, and a red Exit icon — no `Divider()`
    /// separating it from the content below, since Android's toolbar and
    /// content regions sit flush against each other.
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

    // Matches Android's `MainFrame` placeholder (`MainActivity.kt`): a plain
    // ActionButtonDisabled-gray field with left-aligned black text, no icon.
    // Android's actual placeholder text is a live device-info diagnostic dump
    // (company/product/version, comPort/vendorId/deviceId/UDI/device state,
    // etc.) — out of this reskin's scope, kept as a simple message for now.
    private var placeholderView: some View {
        Text("Select a workflow above")
            .font(.system(size: 24))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(15)
            .background(AndroidPalette.actionButtonDisabled)
    }

    // Matches Android's `StatusBar` composable (`MainActivity.kt`): dark-dark
    // background, left-aligned single-line text, no connectivity dot or
    // trailing device-state text (Android's status bar shows only the one
    // status message string).
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
