import SwiftUI

/// Looks like a field, is not one — nothing here can become first responder.
struct PracticeLine: View {
    let composer: PracticeComposer
    let placeholder: String
    let fontSize: CGFloat

    @State private var caretVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if composer.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color(uiColor: Palette.homeGlyph))
                caret
                Spacer(minLength: 0)
            } else {
                Text(composer.before)
                caret
                Text(composer.after)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: fontSize))
        .foregroundStyle(Color(uiColor: Palette.onLight))
        .lineLimit(1)
        .frame(height: fontSize * 1.6, alignment: .leading)
        .accessibilityElement()
        .accessibilityIdentifier("practiceLine")
        .accessibilityLabel(composer.text)
        .accessibilityValue(composer.isEmpty ? placeholder : composer.text)
    }

    private var caret: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(uiColor: Palette.action))
            .frame(width: 2, height: fontSize * 1.15)
            .opacity(caretVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: caretVisible)
            .onAppear {
                withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                    caretVisible = false
                }
            }
            .accessibilityHidden(true)
    }
}
