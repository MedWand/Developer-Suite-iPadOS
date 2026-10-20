import SwiftUI
import MedWandSDK

/// The camera workflow, laid out as three columns between the title bar and the Capture button:
///
/// - **Controls** (left): the white LED intensity slider, and, in otoscope mode, buttons to move the view, change
///   the circle size, and zoom.
/// - **Preview** (center): the live image, or a hint when there is none.
/// - **Modes** (right): Off, Dermatoscope and Otoscope buttons. The selected mode is outlined in red.
///
/// The move, circle and zoom buttons are disabled while a preview is starting or the camera is off. The title bar, status line and
/// Capture button come from ``WorkflowScaffold``.
struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        WorkflowScaffold(
            title: "Camera",
            contentBackground: .black,
            statusMessage: viewModel.statusMessage
        ) {
            HStack(spacing: 0) {
                controlsPanel
                previewArea
                modesPanel
            }
        } actionButton: {
            WorkflowActionButton(
                title: "Capture",
                state: (viewModel.cameraMode == .off || viewModel.previewImage == nil) ? .disabled : .idle,
                action: viewModel.capture
            )
        }
        .onDisappear { viewModel.deactivate() }
    }

    // MARK: - Controls (left panel)

    private var controlsPanel: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Controls")
                    .font(.system(size: 14, weight: .bold))

                if viewModel.ledIntensityMax > 0 {
                    Text("White LED: \(viewModel.ledIntensity)")
                        .font(.system(size: 12))
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.ledIntensity) },
                            set: { viewModel.setLedIntensity(Int($0)) }
                        ),
                        in: 0...Double(viewModel.ledIntensityMax)
                    )
                }

                if viewModel.cameraMode == .otoscope {
                    Text("Move").font(.system(size: 12))
                    controlButton("▲") { viewModel.move(vertical: -1) }
                    HStack(spacing: 4) {
                        controlButton("◀") { viewModel.move(horizontal: -1) }
                        controlButton("▶") { viewModel.move(horizontal: 1) }
                    }
                    controlButton("▼") { viewModel.move(vertical: 1) }

                    Text("Circle").font(.system(size: 12))
                    HStack(spacing: 4) {
                        controlButton("−") { viewModel.adjustRadius(-1) }
                        controlButton("+") { viewModel.adjustRadius(1) }
                    }

                    Text("Zoom").font(.system(size: 12))
                    HStack(spacing: 4) {
                        controlButton("−") { viewModel.zoom(-1) }
                        controlButton("+") { viewModel.zoom(1) }
                    }
                }
            }
            .padding(6)
        }
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(AndroidPalette.buttonFace)
    }

    // A small button for the Controls panel. Disabled while a preview is starting or the camera is off.
    private func controlButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(size: 11))
            .frame(height: 30)
            .padding(.horizontal, 7)
            .disabled(viewModel.isStarting || viewModel.cameraMode == .off)
    }

    // MARK: - Preview (center)

    private var previewArea: some View {
        ZStack {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(viewModel.isStarting ? "Starting camera preview..." : "Select Dermatoscope or Otoscope")
                    .font(.system(size: 18))
                    .foregroundStyle(AndroidPalette.controlDark)
                    .multilineTextAlignment(.center)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Modes (right panel)

    private var modesPanel: some View {
        VStack(spacing: 7) {
            Text("Modes")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(AndroidPalette.highlight)

            modeButton(.off, icon: "none_hover", label: "Off")
            modeButton(.dermatoscope, icon: "dermatoscope_hover", label: "Dermatoscope")
            modeButton(.otoscope, icon: "otoscope_hover", label: "Otoscope")

            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(width: 118)
        .frame(maxHeight: .infinity)
        .background(AndroidPalette.controlDark)
    }

    // One button of the Modes panel. Outlined in red when selected, and grayed while a mode change is in progress.
    private func modeButton(_ mode: CameraMode, icon: String, label: String) -> some View {
        let selected = viewModel.cameraMode == mode
        return Button {
            viewModel.selectMode(mode)
        } label: {
            VStack(spacing: 3) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 46)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AndroidPalette.controlText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 91)
        }
        .background(viewModel.isStarting ? Color(white: 0.9) : .white)
        .overlay(
            Rectangle().strokeBorder(selected ? .red : .white, lineWidth: selected ? 2 : 1)
        )
        .disabled(viewModel.isStarting)
    }
}
