import UIKit

/// One key. Owns its own look so the controller only has to say what the
/// key *is*, never how to paint it.
///
/// It is a plain view holding a label rather than a `UILabel` subclass, and
/// that is load-bearing: a `CAGradientLayer` added to a label's own layer
/// renders *above* the text the label draws, so every key came out blank.
/// The gradient belongs to the view; the label sits on top of it.
///
/// The gradient matters more than it sounds. A grid of flat pastels reads
/// as one sheet of colour and the edges between adjacent cells of the same
/// class disappear. A gentle vertical fall-off, plus a border tinted from
/// the fill itself, gives every key its own edge without the heavy grey
/// outline that made an earlier version look like a spreadsheet.
final class KeyView: UIView {
    private let gradient = CAGradientLayer()
    private let label = UILabel()

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    var attributedText: NSAttributedString? {
        get { label.attributedText }
        set { label.attributedText = newValue }
    }

    /// What the key is called, for VoiceOver and for the UI tests, when
    /// what it *draws* is a glyph. The design draws Home, Categories, the
    /// hide-keyboard key and the arrow as symbols; they still have names.
    var spokenLabel: String? {
        get { label.accessibilityLabel }
        set { label.accessibilityLabel = newValue }
    }

    /// The size the label would like to be. What it actually gets is
    /// whatever also fits the key's height — see `fitFont`.
    private var baseFont: UIFont = .systemFont(ofSize: 21, weight: .semibold)

    var font: UIFont {
        get { label.font }
        set { baseFont = newValue; label.font = newValue; setNeedsLayout() }
    }

    var textColor: UIColor {
        get { label.textColor }
        set { label.textColor = newValue }
    }

    /// Three lines for words and phrases, one for the control keys.
    ///
    /// Control labels are single words, and given two lines "Categories"
    /// breaks across them as "Categor / ies" rather than shrinking. Phrases
    /// need the opposite: "I use this to talk" and "nice to meet you" have
    /// to be allowed to wrap and to shrink, because a key that reads
    /// "nice to meet" says something the user did not mean. Truncation is
    /// never an acceptable outcome here — small text is.
    var lines: Int {
        get { label.numberOfLines }
        set {
            label.numberOfLines = newValue
            label.minimumScaleFactor = newValue == 1 ? 0.5 : 0.45
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.addSublayer(gradient)

        label.numberOfLines = 3
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        // Wrapping before shrinking keeps every label in one comfortable
        // size band; at 0.5 the longest labels became the hardest to read.
        label.lineBreakMode = .byWordWrapping
        label.minimumScaleFactor = 0.45
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        // The label fills the key rather than floating in its middle: a
        // centred label has no height to wrap into, which silently clipped
        // "thank you" down to "thank".
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        fitFont()
    }

    /// Shrinks the label until the whole label fits the key.
    ///
    /// `adjustsFontSizeToFitWidth` only ever fits the *width*, so on a
    /// short key a phrase that needs three lines is silently clipped to two
    /// — which is how "how are you" came to read "how are". A key that says
    /// something the user did not mean is worse than a key with small text,
    /// so height wins and the type gets smaller.
    private func fitFont() {
        guard label.attributedText == nil, let text = label.text, !text.isEmpty else { return }
        let available = CGSize(width: max(bounds.width - 8, 1), height: max(bounds.height - 6, 1))
        var size = baseFont.pointSize
        let floorSize = baseFont.pointSize * label.minimumScaleFactor
        while size > floorSize {
            let candidate = baseFont.withSize(size)
            let height = (text as NSString).boundingRect(
                with: CGSize(width: available.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: candidate], context: nil).height
            if height <= available.height { break }
            size -= 1
        }
        if label.font.pointSize != size { label.font = baseFont.withSize(size) }
    }

    /// - Parameters:
    ///   - fill: the key's own colour, which survives the focus state
    ///     because it is what the user is aiming by.
    ///   - focused: the finger is on this key but has not committed.
    ///   - bordered: false for a key the design draws with no card at all —
    ///     Home sits directly on the tray. The focus ring still appears,
    ///     because explore-then-commit needs it on every key.
    func paint(fill: UIColor, focused: Bool, bordered: Bool = true) {
        let resolvedFill = fill.resolvedColor(with: traitCollection)
        let base = focused ? resolvedFill.shifted(by: 0.18) : resolvedFill
        gradient.colors = base.keyGradient
        layer.borderWidth = focused ? 4 : (bordered ? 1 : 0)
        let border = focused
            ? Palette.focus.resolvedColor(with: traitCollection)
            : base.darkened(by: 0.16)
        layer.borderColor = border.cgColor
    }
}
