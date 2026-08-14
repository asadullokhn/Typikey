import UIKit

/// Routes raw touches to the controller so keys commit on lift-off
/// rather than touch-down.
final class TrackingView: UIView, UIInputViewAudioFeedback {
    weak var controller: KeyboardViewController?

    var enableInputClicksWhenVisible: Bool { true }

    // Let touches above the keyboard band fall through to the app instead
    // of being swallowed by a transparent, oversized container.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let controller, point.y < controller.layoutYOffset { return nil }
        return super.hitTest(point, with: event)
    }

    private func send(_ touches: Set<UITouch>, _ phase: TouchSample.Phase) -> Bool {
        guard let touch = touches.first else { return false }
        controller?.handleTouch(TouchSample(
            point: touch.location(in: self), timestamp: touch.timestamp, phase: phase))
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = send(touches, .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = send(touches, .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = send(touches, .ended)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !send(touches, .cancelled) { controller?.touchCancelled() }
    }
}
