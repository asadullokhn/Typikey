import SwiftUI

/// The app's home screen, as Keiko drew it.
///
/// One screen, not a list of cards leading to one. The page controls sit
/// across the top, the practice field is the whole middle, and the board
/// occupies the bottom — exactly where the keyboard rises, which is why
/// the design's first screen shows the real keyboard there and the rest
/// show the editor. Tap the field and the board steps aside for the thing
/// it is a picture of.
///
/// The panel is not a picture in the loose sense: it is the keyboard's own
/// geometry, eleven columns by four rows, pinned column and all. Editing a
/// board at some other size is guesswork, and the person who pays for a
/// wrong guess is the one who has to find the word again with a joystick.
///
/// Two modes, as drawn. Normally the page is just shown, and keys that
/// open other pages open them here too. `Edit Page` turns blue, `Setup`
/// becomes `Done`, and every content key becomes tappable: tap one and you
/// get the three things that decide what a key is — what it says, what it
/// looks like, and where it goes.
struct BoardHomeView: View {
    @StateObject private var store = PageStore()
    @State private var editing = false
    @State private var selected: Int?
    @State private var confirmingDelete = false
    @State private var practiceText = ""
    @State private var typing = false
    @State private var showingSetup = false
    @State private var showingOnboarding = false
    @AppStorage("onboardingSeen") private var onboardingSeen = false

    var body: some View {
        VStack(spacing: 18) {
            if !store.keyboardCanSeeEdits { fullAccessWarning }
            actions
            header
            Spacer(minLength: 0)
            // While the real keyboard is up it covers this exactly, so
            // drawing a second board underneath it is noise at best and a
            // wrong picture at worst.
            if !typing {
                pagePicker
                board
            }
        }
        .padding(20)
        .background(Color(.systemGray3))
        // The board is meant to be covered, not shoved upwards.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Cancel is the prominent one, as drawn. The dangerous button
        // should never be the easy one to hit by accident.
        .alert("Are you sure you want to delete?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteCurrentPage(); selected = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the keyboard page along with all its contents or buttons.")
        }
        .sheet(isPresented: $showingSetup) { SetupView() }
        .fullScreenCover(isPresented: $showingOnboarding) { OnboardingView() }
        // First run only, and never under UI test: the suite drives this
        // screen straight into the keyboard, and a cover over it would be
        // testing the cover.
        .onAppear {
            guard !onboardingSeen,
                  !ProcessInfo.processInfo.arguments.contains("-skipOnboarding") else { return }
            onboardingSeen = true
            showingOnboarding = true
        }
    }

    /// Without Full Access the keyboard reads its own sandbox, so nothing
    /// arranged here reaches it. The board still works — it falls back to
    /// the shipped one, which is the right direction to fail — but it
    /// fails silently, and somebody could spend an hour on a board that
    /// was never going to appear. Say so before the hour, not after.
    private var fullAccessWarning: some View {
        Button { showingOnboarding = true } label: {
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
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: Across the top

    /// Four slots in both modes, so nothing moves when you start editing.
    /// The fourth is the way out of whichever mode you are in: `Done` while
    /// editing, and otherwise `Setup` — the design draws no door to the
    /// permissions and settings, and a screen you cannot leave is not a
    /// home screen.
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
            // Home is not editable: the keyboard rebuilds it from the
            // sentence so far, so there is nothing fixed here to edit.
            // Categories are where arranging pays off, and where it is
            // safe (team decision, Ali, 11 Aug 2026).
            ActionCard(title: "Edit Page", systemImage: "square.and.pencil",
                       tint: .accentColor, filled: editing,
                       enabled: store.canEditCurrentPage) {
                editing = true
            }
            if editing {
                ActionCard(title: "Done", systemImage: "checkmark",
                           tint: .accentColor, filled: selected == nil) {
                    editing = false
                    selected = nil
                }
            } else {
                ActionCard(title: "Setup", systemImage: "gearshape",
                           tint: .accentColor, filled: false) {
                    showingSetup = true
                }
            }
        }
    }

    /// The instruction only exists while it is true, and the page's name
    /// sits beside it because renaming a page you cannot see the name of
    /// is how two pages end up called the same thing.
    ///
    /// Out of edit mode this whole row is the practice field, which is the
    /// first thing anyone should do with a keyboard app: type with it.
    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            if editing {
                Text("Tap a button\nto edit it.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.turn.right.down")
                    .font(.title)
                    .foregroundStyle(.white)
                Spacer()
                VStack(spacing: 2) {
                    Text("Name of Page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Name of Page", text: $store.currentName)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    PlainTextView(text: $practiceText,
                                  placeholder: "Tap a key from your keyboard.",
                                  minHeight: 44,
                                  font: .systemFont(ofSize: 30, weight: .bold),
                                  onFocusChange: { typing = $0 })
                    Divider().overlay(Color.white.opacity(0.5))
                }
            }
        }
    }

    /// Which board is on screen. The design labels it — "List of
    /// Categories" in Keiko's first screen — and making that label the way
    /// you change page adds no chrome she did not draw. Something has to
    /// do it: a page you add and cannot navigate off is a trap.
    private var pagePicker: some View {
        Menu {
            ForEach(store.pages) { page in
                Button {
                    store.go(to: page.id)
                    editing = false
                    selected = nil
                } label: {
                    Label(page.name,
                          systemImage: page.id == store.currentPageID ? "checkmark" : "square.grid.2x2")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(store.currentName).font(.headline)
                Image(systemName: "chevron.down").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if store.hiddenWordCount > 0 {
                Text("\(store.hiddenWordCount) more word\(store.hiddenWordCount == 1 ? "" : "s") "
                     + "than this page has room for")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: The keyboard, at its own geometry

    /// Eleven columns by four rows of squares, sized by the width they are
    /// given. The pinned column is the keyboard's own — identical on every
    /// board by design (invariant 9) — and the editor shows it without
    /// offering to change it.
    private var board: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<KeyboardPage.rows, id: \.self) { row in
                GridRow {
                    let pinned = PageStore.pinned[row]
                    ControlKey(label: pinned,
                               action: pinned == "Home" ? { store.goHome() } : nil)
                    ForEach(0..<KeyboardPage.columns, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        let index = row * KeyboardPage.columns + column
        if let fixed = PageStore.fixedControl(row: row, column: column) {
            ControlKey(label: fixed, tint: PageStore.tint(for: fixed))
        } else {
            ButtonKey(button: store.button(at: index),
                      editing: editing,
                      isSelected: selected == index) {
                if editing {
                    selected = (selected == index) ? nil : index
                } else if let destination = store.button(at: index)?.destination {
                    store.go(to: destination)
                }
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

/// A square that fills whatever column width the grid hands it.
private extension View {
    func keyShape(_ fill: Color) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct ControlKey: View {
    let label: String
    var tint: Color = Color(.systemGray2)
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            Group {
                if label.hasPrefix("sf:") {
                    Image(systemName: String(label.dropFirst(3)))
                        .font(.title2.weight(.semibold))
                } else {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                }
            }
            .keyShape(tint)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct ButtonKey: View {
    let button: BoardButton?
    let editing: Bool
    let isSelected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                if let label = button?.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
                if let image = button?.image {
                    Text(image).font(.title2)
                }
            }
            .keyShape(PageStore.tint(forWord: button?.label))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
