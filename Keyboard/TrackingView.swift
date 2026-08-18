import UIKit

/// The container the board sits in. Touches on the keys are the grid's own
/// now; this only keeps the transparent area above the board from
/// swallowing taps meant for the app behind it.
final class TrackingView: UIView, UIInputViewAudioFeedback {
    weak var controller: KeyboardViewController?

    var enableInputClicksWhenVisible: Bool { true }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let controller, point.y < controller.layoutYOffset { return nil }
        return super.hitTest(point, with: event)
    }
}
