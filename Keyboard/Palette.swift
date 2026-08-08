import UIKit

/// The keyboard's whole visual system, in one place, following the team's
/// design exports (ExportsOfNewDesign, 7 Aug 2026).
///
/// The rule a user has to learn is one sentence: **light keys put words on
/// the screen; grey keys change the board or fix what you wrote, and the
/// blue ones are the two that finish a message.** Before this, punctuation,
/// letters, category tiles and the delete keys were four different shades
/// of grey — indistinguishable at a glance despite doing entirely
/// different things.
///
/// Fixed (non-adaptive) colours on purpose: an AAC board must look
/// identical in every lighting mode, because it is navigated by remembered
/// colour and position rather than read fresh each time.
enum Palette {

    // MARK: Word classes (Fitzgerald key, softened to match the design)

    static let pronoun = UIColor(red: 0.98, green: 0.96, blue: 0.72, alpha: 1)     // yellow
    static let verb = UIColor(red: 0.80, green: 0.91, blue: 0.72, alpha: 1)        // green
    static let descriptor = UIColor(red: 0.86, green: 0.93, blue: 0.98, alpha: 1)  // blue
    static let noun = UIColor(red: 1.00, green: 0.87, blue: 0.72, alpha: 1)        // orange
    static let social = UIColor(red: 0.99, green: 0.85, blue: 0.91, alpha: 1)      // pink
    static let question = UIColor(red: 0.90, green: 0.85, blue: 0.98, alpha: 1)    // purple
    static let negative = UIColor(red: 0.98, green: 0.72, blue: 0.72, alpha: 1)    // salmon
    /// Prepositions, conjunctions, articles — the Fitzgerald key's white
    /// class. Warm off-white so it separates from the punctuation keys
    /// without leaving the "light writes" family: these words do write,
    /// they just carry grammar rather than meaning.
    static let function = UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1)

    /// Types a character — letters, numbers, punctuation. Word cells carry
    /// their class colour instead, but sit in the same light family, so
    /// "light writes" holds for all of them.
    static let paper = UIColor.white

    // MARK: Roles

    /// Moves you somewhere: Home, Categories, abc/123, EN/MS, size, cursors,
    /// dismiss. Near-white with a blue glyph, as in the team's exports —
    /// travelling is not the same act as erasing, and should not look it.
    static let navigate = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    /// Takes something away: delete, word-delete, clear all. The only grey
    /// keys on the board, so "this removes something" reads at a glance.
    static let erase = UIColor(red: 0.76, green: 0.77, blue: 0.79, alpha: 1)
    /// Finishes the message: Enter, and the send arrow.
    static let action = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1)
    /// Clear all, once armed — the only irreversible key on the board.
    static let destructive = UIColor(red: 0.84, green: 0.24, blue: 0.24, alpha: 1)
    /// Changes what the other keys say: the tense selector. Neither light
    /// (it writes nothing) nor grey (it removes nothing) nor blue (it
    /// finishes nothing), so it gets a colour of its own — mid-tone violet,
    /// deep enough to read as a mode rather than a word.
    static let grammar = UIColor(red: 0.45, green: 0.40, blue: 0.66, alpha: 1)

    // MARK: Chrome

    /// The tray the keys sit on.
    static let board = UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1)
    /// The tray in private mode. Unmistakably different at a glance, because
    /// "is this being remembered?" must be answerable without reading
    /// anything — the keys themselves stay exactly as they were.
    static let privateBoard = UIColor(red: 0.36, green: 0.31, blue: 0.47, alpha: 1)
    /// Hairline around every key — what separates two pale cells.
    static let keyBorder = UIColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
    /// Suggestion pill: near-white blue with a blue hairline and blue text.
    static let suggestionFill = UIColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1)
    static let suggestionBorder = UIColor(red: 0.68, green: 0.82, blue: 0.98, alpha: 1)

    /// Ring drawn around the key under the finger. Explore-then-commit only
    /// works if "which key am I on" is unmistakable, so the highlight is a
    /// thick ring plus a shade shift rather than a colour swap — the class
    /// colour has to survive, since that is what the user is aiming by.
    static let focus = UIColor(red: 0.00, green: 0.42, blue: 0.90, alpha: 1)

    static let onLight = UIColor.black
    static let onDark = UIColor.white

    /// Roles rendered dark enough to need white text.
    static func foreground(on background: UIColor) -> UIColor {
        if background == action || background == destructive || background == grammar { return onDark }
        if background == navigate { return action } // blue glyphs on near-white
        return onLight
    }
}

extension UIColor {
    /// The two stops of a key's fill. The design gives every key a gentle
    /// vertical gradient — lighter at the top — which is what stops a grid
    /// of flat pastels from reading as a single sheet of colour.
    var keyGradient: [CGColor] {
        [lightened(by: 0.10).cgColor, darkened(by: 0.06).cgColor]
    }

    func lightened(by amount: CGFloat) -> UIColor { blended(toward: 1, amount: amount) }
    func darkened(by amount: CGFloat) -> UIColor { blended(toward: 0, amount: amount) }

    private func blended(toward target: CGFloat, amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        return UIColor(red: r + (target - r) * amount,
                       green: g + (target - g) * amount,
                       blue: b + (target - b) * amount, alpha: a)
    }

    /// Shifts a colour toward black or white by `amount` (0-1). Used for the
    /// focus state: light keys deepen, dark keys lift, so every key visibly
    /// reacts no matter where it sits on the scale.
    func shifted(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let isDark = (0.299 * r + 0.587 * g + 0.114 * b) < 0.5
        let target: CGFloat = isDark ? 1 : 0
        return UIColor(
            red: r + (target - r) * amount,
            green: g + (target - g) * amount,
            blue: b + (target - b) * amount,
            alpha: a)
    }
}
