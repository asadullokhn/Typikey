import SwiftUI

/// The board editor, from Keiko's design.
///
/// The panel is not a picture of the keyboard — it is the keyboard's own
/// geometry, eleven columns by four rows, pinned column and all. Editing a
/// board at some other size is guesswork, and the person who pays for a
/// wrong guess is the one who has to find the word again with a joystick.
///
/// Two modes, as drawn. Normally the page is just shown. `Edit Page` turns
/// blue, a fourth `Done` appears, and every content key becomes tappable:
/// tap one and you get the three things that decide what a key is — what
/// it says, what it looks like, and where it goes.
struct PagesView: View {
    @StateObject private var store = PageStore()
    @State private var editing = false
    @State private var selected: Int?
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 20) {
            if !store.keyboardCanSeeEdits { fullAccessWarning }
            actions
            header
            board
        }
        .padding(20)
        .background(Color(.systemGray3))
        .navigationBarTitleDisplayMode(.inline)
        // Cancel is the prominent one, as drawn. The dangerous button
        // should never be the easy one to hit by accident.
        .alert("Are you sure you want to delete?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteCurrentPage(); selected = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the keyboard page along with all its contents or buttons.")
        }
    }

    /// Without Full Access the keyboard reads its own sandbox, so nothing
    /// arranged here reaches it. The board still works — it falls back to
    /// the shipped one, which is the right direction to fail — but it
    /// fails silently, and somebody could spend an hour on a board that
    /// was never going to appear. Say so before the hour, not after.
    private var fullAccessWarning: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("The keyboard cannot see these boards yet")
                    .font(.headline)
                Text("Settings > General > Keyboard > Keyboards > Typikey > Allow Full Access. "
                     + "Until then Typikey keeps using its built-in boards.")
                    .font(.subheadline)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Across the top

    private var actions: some View {
        HStack(spacing: 12) {
            ActionCard(title: "Delete Page", systemImage: "trash", tint: .red,
                       filled: false, enabled: store.canDeleteCurrentPage) {
                confirmingDelete = true
            }
            ActionCard(title: "Add New Page", systemImage: "plus", tint: .primary, filled: false) {
                store.addPage()
                editing = true
            }
            ActionCard(title: "Edit Page", systemImage: "square.and.pencil",
                       tint: .accentColor, filled: editing) {
                editing = true
            }
            if editing {
                ActionCard(title: "Done", systemImage: "checkmark",
                           tint: .accentColor, filled: selected == nil) {
                    editing = false
                    selected = nil
                }
            }
        }
    }

    /// The instruction only exists while it is true, and the page's name
    /// sits beside it because renaming a page you cannot see the name of
    /// is how two pages end up called the same thing.
    private var header: some View {
        HStack(alignment: .top) {
            if editing {
                Text("Tap a button\nto edit it.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.turn.right.down")
                    .font(.title)
                    .foregroundStyle(.white)
            } else {
                Text(store.previewText.isEmpty ? "Tap a key from your keyboard." : store.previewText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Name of Page")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Name of Page", text: $store.currentName)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .disabled(!editing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(editing ? 1 : 0.6),
                        in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: The keyboard, at its own geometry

    private var board: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 6
            let width = (geometry.size.width - spacing * 10) / 11
            let height = min(width, (geometry.size.height - spacing * 3) / 4)

            HStack(alignment: .top, spacing: spacing) {
                // The pinned column, which the editor shows and does not
                // let you change: these four are the keyboard's own
                // controls, not the page's, and they are identical on
                // every board by design (invariant 9).
                VStack(spacing: spacing) {
                    ForEach(PageStore.pinned, id: \.self) { control in
                        ControlKey(label: control, width: width, height: height)
                    }
                }
                VStack(spacing: spacing) {
                    ForEach(0..<KeyboardPage.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<KeyboardPage.columns, id: \.self) { column in
                                cell(row: row, column: column, width: width, height: height)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 420)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func cell(row: Int, column: Int, width: CGFloat, height: CGFloat) -> some View {
        let index = row * KeyboardPage.columns + column
        if let fixed = PageStore.fixedControl(row: row, column: column) {
            ControlKey(label: fixed, width: width, height: height, tint: PageStore.tint(for: fixed))
        } else {
            ButtonKey(button: store.button(at: index),
                      width: width, height: height,
                      editing: editing,
                      isSelected: selected == index) {
                guard editing else { return }
                selected = (selected == index) ? nil : index
            }
            .popover(isPresented: Binding(
                get: { selected == index },
                set: { if !$0, selected == index { selected = nil } })) {
                ButtonEditor(button: store.binding(at: index),
                             pages: store.pages,
                             currentPageID: store.currentPageID) {
                    selected = nil
                }
                .frame(minWidth: 380, minHeight: 460)
            }
        }
    }
}

// MARK: - The key editor

/// What Keiko's popover asks, in her order: what it says, what it looks
/// like, where it goes.
private struct ButtonEditor: View {
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
private struct SymbolPicker: View {
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

// MARK: - Keys

private struct ControlKey: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    var tint: Color = Color(.systemGray2)

    var body: some View {
        Group {
            if label.hasPrefix("sf:") {
                Image(systemName: String(label.dropFirst(3)))
                    .font(.system(size: min(width, height) * 0.42, weight: .semibold))
            } else {
                Text(label)
                    .font(.system(size: min(width, height) * 0.24, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: width, height: height)
        .background(tint, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.primary)
    }
}

private struct ButtonKey: View {
    let button: BoardButton?
    let width: CGFloat
    let height: CGFloat
    let editing: Bool
    let isSelected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                if let label = button?.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: min(width, height) * 0.22, weight: .semibold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                if let image = button?.image {
                    Text(image).font(.system(size: min(width, height) * 0.4))
                }
            }
            .frame(width: width, height: height)
            .background(PageStore.tint(forWord: button?.label), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.black.opacity(button == nil ? 0 : 0.7),
                            lineWidth: isSelected ? 3 : (button == nil ? 0 : 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(!editing)
    }
}

/// One of the actions across the top. `filled` is the design's way of
/// saying which mode you are in — Edit Page turns solid while editing, and
/// Done turns solid once there is nothing half-finished to come back to.
private struct ActionCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    var filled = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 28, weight: .medium))
                Text(title).font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(filled ? tint : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(filled ? .white : (enabled ? tint : Color.secondary))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
