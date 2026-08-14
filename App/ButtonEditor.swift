import SwiftUI

/// What Keiko's popover asks, in her order: what it says, what it looks
/// like, where it goes.
struct ButtonEditor: View {
    @Binding var button: BoardButton
    let pages: [KeyboardPage]
    let currentPageID: String
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: done) {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.title2.weight(.bold))
                            Text("Done").font(.headline)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(button.label.isEmpty ? Color(.systemBackground) : Color.accentColor,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(button.label.isEmpty ? Color.accentColor : .white)
                    }
                    .buttonStyle(.plain)
                }

                field("Button Label") {
                    TextField("", text: $button.label)
                        .font(.title3)
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                field("Select Image") {
                    SymbolPicker(selection: $button.image)
                }

                field("Navigate to Page") {
                    Menu {
                        Button("None") { button.destination = nil }
                        ForEach(pages.filter { $0.id != currentPageID }) { page in
                            Button(page.name) { button.destination = page.id }
                        }
                    } label: {
                        HStack {
                            Image(systemName: button.destination == nil
                                  ? "circle" : "checkmark.circle.fill")
                            Text(destinationName)
                                .foregroundStyle(button.destination == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var destinationName: String {
        guard let id = button.destination else { return "Select Keyboard Page" }
        return pages.first { $0.id == id }?.name ?? "Select Keyboard Page"
    }

    private func field(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }
}

/// Emoji, until the drawn symbols arrive.
///
/// Keiko's tiles carry line-art pictograms — those are licensed artwork
/// (ARASAAC is CC BY-NC-SA, PCS is Boardmaker's) and a decision of their
/// own, so this picks from what already ships rather than pretending the
/// art is done. What crosses to the keyboard is a name either way, so
/// swapping the source later changes nothing here.
struct SymbolPicker: View {
    @Binding var selection: String?

    private let choices = ["🍽️", "🥤", "🚶", "🤝", "❤️", "👉", "🙋", "✋", "📺", "🎨",
                           "📖", "✍️", "🎮", "🏠", "🏫", "😊", "😢", "😴", "⏰", "🚻"]

    var body: some View {
        VStack(spacing: 12) {
            if let selection {
                Text(selection).font(.system(size: 78))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 44))
                    Text("Tap to select image").foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 6) {
                Button { selection = nil } label: {
                    Image(systemName: "nosign").font(.title3).frame(height: 30)
                }
                .buttonStyle(.plain)
                ForEach(choices, id: \.self) { symbol in
                    Button { selection = symbol } label: {
                        Text(symbol).font(.title2).frame(height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
