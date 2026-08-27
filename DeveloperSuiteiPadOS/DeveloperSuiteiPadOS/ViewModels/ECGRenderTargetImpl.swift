import Foundation
import MedWandSDK

/// Conforms to `ECGRenderTarget` and republishes each composited frame via a
/// callback — pattern modeled on `FunctionalTest`'s own reference
/// implementation. Uses `ECGModule`'s default render size rather than
/// tracking the view's live layout size (a deliberate simplification vs.
/// Android's `EcgGridContainer.Resized`, documented in docs/DESIGN.md).
struct ECGRenderTargetImpl: ECGRenderTarget {
    let width = ECGModule.defaultRenderWidth
    let height = ECGModule.defaultRenderHeight

    private let renderCallback: @Sendable (ECGFrameImage) -> Void

    init(renderCallback: @Sendable @escaping (ECGFrameImage) -> Void) {
        self.renderCallback = renderCallback
    }

    func render(_ image: ECGFrameImage) { renderCallback(image) }
}
