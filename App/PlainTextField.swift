import SwiftUI
import UIKit

/// A text view with iPadOS's shortcuts bar switched off — the strip of
/// undo / redo / paste buttons the system floats above the keyboard.
///
/// That bar belongs to the text field being typed into, not to the
/// keyboard, so it can only be removed by the app that owns the field:
/// `inputAssistantItem` with no button groups. Typikey can therefore clear
/// it in its own screens, and cannot clear it in Notes or Messages — no
/// API lets a keyboard extension touch its host's assistant bar.
///
/// Worth removing here because those buttons are small, close together,
/// and sit directly above the large keys this whole keyboard exists to
/// provide — a mis-tap on "paste" in the middle of a sentence is exactly
/// the kind of error that costs a user with limited motor control minutes.
struct PlainTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 120
    var font: UIFont = .preferredFont(forTextStyle: .title3)
    /// Called when the field takes or gives up the keyboard. The home
    /// screen draws the board where the keyboard will appear, so it needs
    /// to know when the real one is about to cover it.
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = font
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.inputAssistantItem.leadingBarButtonGroups = []
        view.inputAssistantItem.trailingBarButtonGroups = []
        view.setContentHuggingPriority(.defaultLow, for: .vertical)

        let label = UILabel()
        label.text = placeholder
        label.font = font
        label.textColor = .placeholderText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight),
        ])
        context.coordinator.placeholderLabel = label
        label.isHidden = !text.isEmpty
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, focus: onFocusChange) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>
        private let focus: (Bool) -> Void
        var placeholderLabel: UILabel?

        init(text: Binding<String>, focus: @escaping (Bool) -> Void) {
            self.text = text
            self.focus = focus
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
        }

        func textViewDidBeginEditing(_ textView: UITextView) { focus(true) }
        func textViewDidEndEditing(_ textView: UITextView) { focus(false) }
    }
}
