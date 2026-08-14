import UIKit

enum WordClass: CaseIterable {
    case pronoun, verb, descriptor, noun, social, question, function, punct
}

func luminance(_ color: UIColor, traits: UITraitCollection) -> CGFloat {
    let resolved = color.resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    precondition(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
    return red * 0.299 + green * 0.587 + blue * 0.114
}

let light = UITraitCollection(userInterfaceStyle: .light)
let dark = UITraitCollection(userInterfaceStyle: .dark)

precondition(luminance(Palette.board, traits: light) > 0.9,
             "the light keyboard tray must remain white")
precondition(luminance(Palette.board, traits: dark) < 0.15,
             "the keyboard tray must become dark with the system")
precondition(luminance(Palette.paper, traits: dark) < 0.3,
             "character keys must not remain white in dark mode")
precondition(luminance(Palette.suggestionFill, traits: dark) < 0.3,
             "the suggestion bar must follow dark mode")

let darkText = Palette.foreground(on: Palette.paper)
precondition(luminance(darkText, traits: dark) > 0.8,
             "dark-mode keys need light labels")
precondition(luminance(darkText, traits: light) < 0.2,
             "light-mode keys need dark labels")

for wordClass in WordClass.allCases {
    precondition(luminance(Palette.color(for: wordClass), traits: dark) < 0.5,
                 "every Fitzgerald key color needs a dark-mode variant")
}

func fontWeight(_ font: UIFont) -> CGFloat {
    let traits = font.fontDescriptor.object(forKey: .traits)
        as? [UIFontDescriptor.TraitKey: Any]
    return (traits?[.weight] as? NSNumber)?.doubleValue ?? 0
}

let normalTextTraits = UITraitCollection { traits in
    traits.preferredContentSizeCategory = .large
    traits.legibilityWeight = .regular
}
let largerTextTraits = UITraitCollection { traits in
    traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    traits.legibilityWeight = .regular
}
let boldTextTraits = UITraitCollection { traits in
    traits.preferredContentSizeCategory = .large
    traits.legibilityWeight = .bold
}

let normalFont = KeyboardTypography.font(
    size: 21, weight: .medium, textStyle: .title3, traits: normalTextTraits)
let largerFont = KeyboardTypography.font(
    size: 21, weight: .medium, textStyle: .title3, traits: largerTextTraits)
let boldFont = KeyboardTypography.font(
    size: 21, weight: .medium, textStyle: .title3, traits: boldTextTraits)

precondition(largerFont.pointSize > normalFont.pointSize,
             "Larger Text must increase key label size")
precondition(fontWeight(boldFont) > fontWeight(normalFont),
             "Bold Text must increase key label weight")
precondition(
    KeyboardTypography.scaledValue(
        26, textStyle: .title2, traits: largerTextTraits)
        > KeyboardTypography.scaledValue(
            26, textStyle: .title2, traits: normalTextTraits),
    "Larger Text must increase keyboard symbols")
