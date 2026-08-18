import SwiftUI

/// The keyboard's key face in SwiftUI. Mirrors `KeyView.paint` and must keep
/// mirroring it. Size comes from the caller's frame: Enter spans two rows.
private struct KeySurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let fill: UIColor
    let bordered: Bool
    let focused: Bool

    func body(content: Content) -> some View {
        let base = fill.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                shape.fill(LinearGradient(
                    colors: [Color(uiColor: base.lightened(by: 0.10)),
                             Color(uiColor: base.darkened(by: 0.06))],
                    startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                shape.strokeBorder(
                    focused ? Color(uiColor: Palette.focus)
                            : Color(uiColor: base.darkened(by: 0.16)),
                    lineWidth: focused ? 4 : (bordered ? 1 : 0))
            )
    }
}

extension View {
    func keyShape(_ fill: UIColor, bordered: Bool = true, focused: Bool = false) -> some View {
        modifier(KeySurface(fill: fill, bordered: bordered, focused: focused))
    }
}

struct ControlKey: View {
    let label: String
    var tint: UIColor = Palette.navigate
    var accessibilityName: String?
    var action: (() -> Void)?

    private var isHome: Bool { label == "sf:house.fill" }

    var body: some View {
        Button { action?() } label: {
            Group {
                if label.hasPrefix("sf:") {
                    Image(systemName: String(label.dropFirst(3)))
                        .font(.system(size: 38, weight: .semibold))
                } else {
                    Text(label)
                        .font(.system(size: 30, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                }
            }
            .keyShape(tint, bordered: !isHome)
            .foregroundStyle(Color(uiColor: isHome ? Palette.homeGlyph
                                                   : Palette.foreground(on: tint)))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(accessibilityName ?? label)
    }
}

struct ButtonKey: View {
    let button: BoardButton?
    let editing: Bool
    let isSelected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                if let label = button?.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 27, weight: .semibold))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
                if let image = button?.image {
                    Text(image).font(.system(size: 37))
                }
            }
            .keyShape(PageStore.tint(forWord: button?.label), focused: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!editing && button == nil)
    }
}
