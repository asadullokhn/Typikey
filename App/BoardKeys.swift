import SwiftUI

// The three kinds of thing the board draws: a control the editor shows
// and will not change, a key belonging to the page, and one of the
// actions across the top.

/// A square that fills whatever column width the grid hands it.
extension View {
    func keyShape(_ fill: Color) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.72), radius: 3, x: 0, y: -1)
            )
            .aspectRatio(1, contentMode: .fit)
    }
}

struct ControlKey: View {
    let label: String
    var tint: Color = Color(.systemGray2)
    var accessibilityName: String?
    var action: (() -> Void)?

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
            .keyShape(tint)
            .foregroundStyle(label == "Enter" ? Color.white : Color.primary)
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
            .keyShape(PageStore.tint(forWord: button?.label))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white : Color.black.opacity(button == nil ? 0 : 0.7),
                            lineWidth: isSelected ? 3 : (button == nil ? 0 : 1))
            )
        }
        .buttonStyle(.plain)
        // Out of edit mode only the doorways do anything, which is how the
        // keyboard itself behaves.
        .disabled(!editing && button?.destination == nil)
    }
}

/// One of the three large actions in the reference's upper-right cluster.
struct ActionCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    var filled = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .regular))
                    .frame(width: 152, height: 152)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(filled ? tint : Color(.systemBackground))
                            .shadow(color: .black.opacity(filled ? 0 : 0.14), radius: 13, y: 4)
                    )
                    .foregroundStyle(filled ? Color.white : Color(.systemGray2))
                Text(title)
                    .font(.system(size: 25, weight: .regular))
                    .lineLimit(1)
                    .foregroundStyle(enabled ? (filled ? tint : Color.primary) : Color.secondary)
            }
            .frame(width: 176)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
