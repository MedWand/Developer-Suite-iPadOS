import SwiftUI
import UIKit

/// Displays the live ECG waveform via a `CALayer` the SDK paints into directly — `AppViewModel`
/// owns `ecgDisplayLayer` for the app's whole lifetime and hands the SDK a reference to it once,
/// at `configure(ecgLayer:)` time; the SDK writes composited frames straight into its `.contents`.
/// This view's job is only to attach/detach that already-existing layer as a sublayer whenever
/// its own backing `UIView` is created/torn down by SwiftUI — it never creates or destroys the
/// layer itself, since the layer's lifetime is tied to the app, not to any one `UIViewRepresentable`
/// instantiation.
struct ECGWaveformView: UIViewRepresentable {
    let layer: CALayer

    // Creates the UIView that hosts the layer.
    func makeUIView(context: Context) -> ECGWaveformUIView {
        ECGWaveformUIView(displayLayer: layer)
    }

    // Nothing to update: the SDK changes the layer's contents itself.
    func updateUIView(_ uiView: ECGWaveformUIView, context: Context) {}

    // Detaches the layer when SwiftUI discards the view, so a later view can host it.
    static func dismantleUIView(_ uiView: ECGWaveformUIView, coordinator: ()) {
        uiView.detachDisplayLayer()
    }
}

/// Backing view for `ECGWaveformView`. Owns no content of its own — just hosts the app-owned
/// display layer for as long as this particular `UIView` instance is alive.
final class ECGWaveformUIView: UIView {
    private let displayLayer: CALayer

    init(displayLayer: CALayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)

        backgroundColor = .white
        layer.addSublayer(displayLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func detachDisplayLayer() {
        displayLayer.removeFromSuperlayer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }
}
