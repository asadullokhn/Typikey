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
///
/// The word-class tints are sampled from TouchChat's own board (screenshots,
/// 19 Aug 2026) rather than chosen, because he already navigates that board
/// by colour and a different yellow for "I" is a different key to him. The
/// class-to-hue assignment is the Modified Fitzgerald Key, which both boards
/// follow; what changed here is the exact tint of each hue.
enum Palette {

    // MARK: Word classes (Fitzgerald key, softened to match the design)

    static let pronoun = adaptive(light: (1.00, 1.00, 0.69), dark: (0.43, 0.43, 0.12))
    static let verb = adaptive(light: (0.71, 0.88, 0.72), dark: (0.19, 0.37, 0.20))
    static let descriptor = adaptive(light: (0.73, 0.94, 0.92), dark: (0.15, 0.43, 0.40))
    static let noun = adaptive(light: (0.98, 0.87, 0.64), dark: (0.43, 0.34, 0.14))
    static let social = adaptive(light: (0.98, 0.88, 0.90), dark: (0.42, 0.22, 0.27))
    static let question = adaptive(light: (0.80, 0.80, 0.95), dark: (0.23, 0.23, 0.42))
    static let negative = adaptive(light: (0.96, 0.79, 0.78), dark: (0.48, 0.20, 0.19))
    /// Prepositions, conjunctions, articles — the Fitzgerald key's white
    /// class, which TouchChat renders as a pale cyan (`and`, `at`, `all`,
    /// `for`, `with`). It sits close to the punctuation keys, and it does
    /// there too: these words write, they just carry grammar rather than
    /// meaning, and that is the distinction the near-match is drawing.
    static let function = adaptive(light: (0.87, 1.00, 1.00), dark: (0.23, 0.24, 0.24))

    /// Types a character — letters, numbers, punctuation. Word cells carry
    /// their class colour instead, but sit in the same light family, so
    /// "light writes" holds for all of them.
    static let paper = adaptive(light: (1.00, 1.00, 1.00), dark: (0.18, 0.18, 0.18))

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
    /// Enter with nothing to send. Dark text on it, not white: white on this
    /// grey measures 2.4:1, under the 3:1 floor even at this size. Once there
    /// is something to send the key turns `action` blue and takes white.
    static let commit = UIColor(white: 0.66, alpha: 1)
    /// Blue, for the things that are blue: the send arrow and the
    /// suggestion pills' text.
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
    /// The tray while a board is being arranged. Same reasoning as private
    /// mode, for the same kind of question: "will this key talk, or will it
    /// open the editor?" has to be answerable before the finger lands, not
    /// after. The keys themselves stay exactly as they were — what changed
    /// is what the board is for, not what any key says.
    static let editingBoard = adaptive(light: (0.28, 0.45, 0.66), dark: (0.12, 0.21, 0.33))

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
