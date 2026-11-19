import SwiftUI
import MedWandSDK

/// The camera workflow, laid out as three columns between the title bar and the Capture button:
///
/// - **Controls** (left): the white LED intensity slider (for a camera whose LED is only on or off, an on/off button),
///   shown while a mode is on, and, in otoscope mode, buttons to move the view, change
///   the circle size, zoom, and a Reset button that restores all three.
/// - **Preview** (center): the live image, or a hint when there is none.
/// - **Modes** (right): Off, Dermatoscope and Otoscope buttons. The selected mode is outlined in red.
///
/// The control buttons are at least 56 x 56 points and are disabled while a preview is starting or the camera is off. Move, circle
/// and zoom repeat while held; Reset acts once. The title bar, status line and
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
                state: (viewModel.cameraMode == .off || viewModel.isStarting) ? .disabled : .idle,
                action: viewModel.capture
            )
        }
        .onDisappear { viewModel.deactivate() }
    }

    // MARK: - Controls (left panel)

    private var controlsPanel: some View {
        ScrollView {
            VStack(spacing: 8) {
                panelLabel("Controls", size: 16, weight: .bold)

                if viewModel.ledIntensityMax > 0 {
                    if viewModel.ledAdjustable {
                        panelLabel("White LED: \(Int(viewModel.ledSliderValue))")
                        LedSlider(
                            value: viewModel.ledSliderValue,
                            maximum: viewModel.ledIntensityMax,
                            onChange: viewModel.ledSliderChanged,
                            onEditingChanged: viewModel.ledEditingChanged
                        )
                        .frame(height: 44)
                        .padding(.vertical, 6)
                    } else {
                        // A camera whose LED is only on or off: a button, as on Android.
                        let ledOn = viewModel.ledSliderValue > 0
                        panelLabel("White LED: \(ledOn ? "On" : "Off")")
                        controlButton(symbol: ledOn ? "lightbulb.fill" : "lightbulb",
                                      label: ledOn ? "Turn white LED off" : "Turn white LED on",
                                      repeats: false) { viewModel.toggleLed() }
                    }
                }

                if viewModel.cameraMode == .otoscope {
                    panelLabel("Move")
                    controlButton(symbol: "arrowtriangle.up.fill", label: "Move up") { viewModel.move(vertical: -1) }
                    HStack(spacing: 8) {
                        controlButton(symbol: "arrowtriangle.left.fill", label: "Move left") { viewModel.move(horizontal: -1) }
                        controlButton(symbol: "arrowtriangle.right.fill", label: "Move right") { viewModel.move(horizontal: 1) }
                    }
                    controlButton(symbol: "arrowtriangle.down.fill", label: "Move down") { viewModel.move(vertical: 1) }

                    panelLabel("Circle")
                    HStack(spacing: 8) {
                        controlButton(symbol: "minus", label: "Smaller circle") { viewModel.adjustRadius(-1) }
                        controlButton(symbol: "plus", label: "Larger circle") { viewModel.adjustRadius(1) }
                    }

                    panelLabel("Zoom")
                    HStack(spacing: 8) {
                        controlButton(symbol: "minus", label: "Zoom out") { viewModel.zoom(-1) }
                        controlButton(symbol: "plus", label: "Zoom in") { viewModel.zoom(1) }
                    }

                    panelLabel("Reset")
                    controlButton(symbol: "arrow.counterclockwise", label: "Reset move, circle and zoom", repeats: false) {
                        viewModel.reset()
                    }
                }
            }
            .padding(6)
        }
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(AndroidPalette.buttonFace)
    }

    // A heading or caption in the Controls panel. The color is set explicitly: the panel is white, and the default text
    // color is white in dark appearance.
    private func panelLabel(_ text: String, size: CGFloat = 14, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(AndroidPalette.controlText)
    }

    // A button for the Controls panel, at least 56 x 56 points. It repeats while held unless `repeats` is false. Disabled
    // while a preview is starting or the camera is off.
    private func controlButton(symbol: String, label: String, repeats: Bool = true,
                               action: @escaping () -> Void) -> some View {
        CameraRepeatButton(symbol: symbol, label: label, repeats: repeats, action: action)
            .disabled(viewModel.isStarting || viewModel.cameraMode == .off)
    }

    // MARK: - Preview (center)

    private var previewArea: some View {
        ZStack {
            CameraLayerView(layer: viewModel.previewLayer)
            if viewModel.cameraMode == .off || viewModel.isStarting {
                Text(viewModel.isStopping ? "Turning the camera off..."
                     : viewModel.isStarting ? "Starting camera preview..."
                     : "Select Dermatoscope or Otoscope")
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

/// Hosts the layer the SDK draws the camera preview into, keeping it the size of the view.
private struct CameraLayerView: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> LayerHostView { LayerHostView(hosted: layer) }

    func updateUIView(_ uiView: LayerHostView, context: Context) {}
}

private final class LayerHostView: UIView {
    private let hosted: CALayer

    init(hosted: CALayer) {
        self.hosted = hosted
        super.init(frame: .zero)
        layer.addSublayer(hosted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hosted.frame = bounds
        CATransaction.commit()
    }
}

/// A Controls panel button that acts when touched and, if held, repeats.
///
/// The face is white with a black outline (as the mode buttons), a darker face while pressed, gray when disabled, and
/// at least 56 x 56 points, all of which is the touch target. The action runs once at touch-down. If the touch is held for
/// ``repeatDelay`` it then runs every ``repeatInterval`` until the touch ends, moves off the button, or the button is
/// disabled. The press is a long-press gesture rather than a drag, so a drag that starts on a button still scrolls the panel.
private struct CameraRepeatButton: View {
    /// How long a touch is held before it starts to repeat.
    static let repeatDelay: Duration = .milliseconds(400)
    /// The time between repeats.
    static let repeatInterval: Duration = .milliseconds(100)

    let symbol: String
    let label: String
    /// `false` for a button that acts once per touch, such as Reset.
    var repeats = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isEnabled ? AndroidPalette.controlText : AndroidPalette.actionButtonDisabled)
            .frame(minWidth: 56, minHeight: 56)
            .background(isPressed ? AndroidPalette.controlDark : AndroidPalette.buttonFace)
            .overlay(Rectangle().strokeBorder(isEnabled ? Color.black : AndroidPalette.actionButtonDisabled, lineWidth: 1))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 20, perform: {}, onPressingChanged: { pressing in
                if pressing { press() } else { release() }
            })
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { release() }
            }
            .onDisappear { release() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    // Runs the action now, and starts repeating after the delay.
    private func press() {
        guard isEnabled, repeatTask == nil else { return }
        isPressed = true
        action()
        guard repeats else { return }
        repeatTask = Task {
            try? await Task.sleep(for: Self.repeatDelay)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: Self.repeatInterval)
            }
        }
    }

    // Ends the press and stops repeating.
    private func release() {
        isPressed = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}

/// The white LED slider: a system `UISlider` (SwiftUI's `Slider` cannot color its thumb, and on iPadOS 26 its glass thumb is
/// invisible on the white panel) with a blue thumb and track.
///
/// The view model owns the value: this control shows `value`, but only while the finger is not on it, and reports each new
/// whole number through `onChange`. It never waits for the device.
private struct LedSlider: UIViewRepresentable {
    let value: Double
    let maximum: Int
    let onChange: (Int) -> Void
    let onEditingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> StepSlider {
        let slider = StepSlider()
        slider.minimumValue = 0
        slider.isContinuous = true
        slider.minimumTrackTintColor = UIColor(AndroidPalette.highlight)
        slider.thumbTintColor = UIColor(AndroidPalette.highlight)
        slider.accessibilityLabel = "White LED"
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ slider: StepSlider, context: Context) {
        context.coordinator.parent = self
        slider.maximumValue = Float(maximum)
        slider.accessibilityStep = Float(max(1, maximum / 20))
        // Never move the thumb while the finger is on it.
        if !slider.isTracking, slider.value != Float(value) {
            slider.value = Float(value)
            context.coordinator.lastWhole = Int(value)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// A `UISlider` that VoiceOver adjusts in whole steps (1 for a small range, a twentieth of the range for a large one).
    final class StepSlider: UISlider {
        var accessibilityStep: Float = 1

        override func accessibilityIncrement() { adjust(by: accessibilityStep) }
        override func accessibilityDecrement() { adjust(by: -accessibilityStep) }
        override var accessibilityValue: String? {
            get { "\(Int(value.rounded()))" }
            set {}
        }

        private func adjust(by step: Float) {
            value = min(maximumValue, max(minimumValue, value.rounded() + step))
            sendActions(for: .valueChanged)
        }
    }

    final class Coordinator: NSObject {
        var parent: LedSlider
        var lastWhole = -1

        init(_ parent: LedSlider) { self.parent = parent }

        @objc func valueChanged(_ slider: UISlider) {
            let whole = Int(slider.value.rounded())
            guard whole != lastWhole else { return }
            lastWhole = whole
            parent.onChange(whole)
        }

        @objc func touchDown(_ slider: UISlider) {
            parent.onEditingChanged(true)
        }

        @objc func touchUp(_ slider: UISlider) {
            slider.value = slider.value.rounded()
            parent.onEditingChanged(false)
        }
    }
}
