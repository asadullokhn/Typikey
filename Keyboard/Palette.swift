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
/// The class hues and positions stay stable between appearances; only their
/// luminance changes so the board follows the iPad without losing the AAC
/// colour map the user navigates by memory.
enum Palette {

    // MARK: Word classes (Fitzgerald key, softened to match the design)

    static let pronoun = adaptive(light: (0.98, 0.96, 0.72), dark: (0.43, 0.38, 0.12))
    static let verb = adaptive(light: (0.80, 0.91, 0.72), dark: (0.19, 0.37, 0.22))
    static let descriptor = adaptive(light: (0.86, 0.93, 0.98), dark: (0.15, 0.31, 0.43))
    static let noun = adaptive(light: (1.00, 0.87, 0.72), dark: (0.43, 0.29, 0.14))
    static let social = adaptive(light: (0.99, 0.85, 0.91), dark: (0.42, 0.22, 0.31))
    static let question = adaptive(light: (0.90, 0.85, 0.98), dark: (0.31, 0.23, 0.42))
    static let negative = adaptive(light: (0.98, 0.72, 0.72), dark: (0.48, 0.19, 0.19))
    /// Prepositions, conjunctions, articles — the Fitzgerald key's white
    /// class. Warm off-white so it separates from the punctuation keys
    /// without leaving the "light writes" family: these words do write,
    /// they just carry grammar rather than meaning.
    static let function = adaptive(light: (0.96, 0.95, 0.91), dark: (0.23, 0.23, 0.24))

    /// Types a character — letters, numbers, punctuation. Word cells carry
    /// their class colour instead, but sit in the same light family, so
    /// "light writes" holds for all of them.
    static let paper = adaptive(light: (1.00, 1.00, 1.00), dark: (0.17, 0.17, 0.18))

    static func color(for wordClass: WordClass) -> UIColor {
        switch wordClass {
        case .pronoun:    return pronoun
        case .verb:       return verb
        case .descriptor: return descriptor
        case .noun:       return noun
        case .social:     return social
        case .question:   return question
        case .function:   return function
        case .punct:      return paper
        }
    }

    // MARK: Roles

    /// Moves you somewhere: Home, Categories, abc/123, EN/MS, size, cursors,
    /// dismiss. Near-white with a blue glyph, as in the team's exports —
    /// travelling is not the same act as erasing, and should not look it.
    static let navigate = adaptive(light: (0.86, 0.86, 0.87), dark: (0.23, 0.23, 0.24))
    /// Takes something away: delete, word-delete, clear all. The only grey
    /// keys on the board, so "this removes something" reads at a glance.
    static let erase = adaptive(light: (0.76, 0.77, 0.79), dark: (0.31, 0.31, 0.33))
    /// Finishes the message: Enter, and the send arrow.
    static let action = adaptive(light: (0.00, 0.48, 1.00), dark: (0.04, 0.52, 1.00))
    /// Clear all, once armed — the only irreversible key on the board.
    static let destructive = adaptive(light: (0.84, 0.24, 0.24), dark: (0.82, 0.18, 0.17))

    // MARK: Chrome

    /// The tray the keys sit on.
    static let board = adaptive(light: (1.00, 1.00, 1.00), dark: (0.07, 0.07, 0.08))
    /// The tray in private mode. Unmistakably different at a glance, because
    /// "is this being remembered?" must be answerable without reading
    /// anything — the keys themselves stay exactly as they were.
    static let privateBoard = adaptive(light: (0.36, 0.31, 0.47), dark: (0.18, 0.14, 0.24))
    /// Suggestion pill: near-white blue with a blue hairline and blue text.
    static let suggestionFill = adaptive(light: (0.95, 0.97, 1.00), dark: (0.12, 0.15, 0.19))
    static let suggestionBorder = adaptive(light: (0.68, 0.82, 0.98), dark: (0.13, 0.42, 0.68))

    /// Ring drawn around the key under the finger. Explore-then-commit only
    /// works if "which key am I on" is unmistakable, so the highlight is a
    /// thick ring plus a shade shift rather than a colour swap — the class
    /// colour has to survive, since that is what the user is aiming by.
    static let focus = adaptive(light: (0.00, 0.42, 0.90), dark: (0.39, 0.82, 1.00))

    static let onLight = adaptive(light: (0.00, 0.00, 0.00), dark: (1.00, 1.00, 1.00))
    static let onDark = UIColor.white
    static let homeGlyph = adaptive(light: (0.58, 0.58, 0.58), dark: (0.78, 0.78, 0.80))

    /// Roles rendered dark enough to need white text.
    static func foreground(on background: UIColor) -> UIColor {
        background == action || background == destructive ? onDark : onLight
    }

    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> UIColor {
        UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        }
    }
}

enum KeyboardTypography {
    static func font(
        size: CGFloat,
        weight: UIFont.Weight,
        textStyle: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> UIFont {
        let effectiveWeight: UIFont.Weight
        if traits.legibilityWeight == .bold {
            effectiveWeight = UIFont.Weight(
                rawValue: min(weight.rawValue + 0.15, UIFont.Weight.black.rawValue))
        } else {
            effectiveWeight = weight
        }
        let base = UIFont.systemFont(ofSize: size, weight: effectiveWeight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(
            for: base,
            maximumPointSize: size * 1.5,
            compatibleWith: traits)
    }

    static func scaledValue(
        _ value: CGFloat,
        textStyle: UIFont.TextStyle,
        traits: UITraitCollection
    ) -> CGFloat {
        min(
            UIFontMetrics(forTextStyle: textStyle).scaledValue(
                for: value, compatibleWith: traits),
            value * 1.5)
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
