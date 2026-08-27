import SwiftUI
import UIKit

/// Displays the live ECG waveform via a single `CALayer` instead of a SwiftUI
/// `Image`. `ECGModule` hands over one already-flattened `CGImage` per frame
/// (see `ECGRenderTarget` in MedWandSDK) — this view assigns it straight to
/// `CALayer.contents`, avoiding a PNG decode and the SwiftUI `Image` view
/// diff on the streaming hot path. Ported from FunctionalTest's reference
/// implementation (design doc §6.6's sequence diagram covers the callback
/// path this feeds from).
struct ECGWaveformView: UIViewRepresentable {
    var image: CGImage?

    func makeUIView(context: Context) -> ECGWaveformUIView {
        ECGWaveformUIView()
    }

    func updateUIView(_ uiView: ECGWaveformUIView, context: Context) {
        uiView.image = image
    }
}

/// Backing view for `ECGWaveformView`. Implicit `contents` animation is
/// disabled — at streaming rate, the default cross-fade would be both
/// wrong-looking and wasted compositing work.
final class ECGWaveformUIView: UIView {
    private let contentLayer = CALayer()

    var image: CGImage? {
        didSet { contentLayer.contents = image }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white
        contentLayer.contentsGravity = .resize
        contentLayer.actions = ["contents": NSNull()]
        layer.addSublayer(contentLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentLayer.frame = bounds
    }
}
