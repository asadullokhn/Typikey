import SwiftUI

/// The configured home screen mirrors the reference at the iPad's native
/// 1366 x 1024 landscape canvas: a centred capsule of three page actions, a
/// wide practice line under a yellow rule, the page identity, and a
/// ten-column keyboard tray sitting on the bottom edge.
struct BoardHomeView: View {
    @StateObject private var store = PageStore()
    @State private var editing = false
    @State private var selected: Int?
    @State private var confirmingDelete = false
    @State private var composer = PracticeComposer()
    @State private var level: PracticeLevel = .page
    @State private var shifted = false
    @State private var namingFocused = false
    @State private var nameBeforeEdit = ""
    @State private var showingSetup = false
    @State private var showingOnboarding = false
    @AppStorage("onboardingSeen") private var onboardingSeen = false

    var body: some View {
        GeometryReader { proxy in
            let fit = HomeFit(size: proxy.size)
            VStack(spacing: 0) {
                actions(fit)
                    .padding(.top, 40 * fit.scale)

                practiceField(fit)
                    .padding(.horizontal, max(48, proxy.size.width * 0.096))
                    .padding(.top, 52 * fit.scale)

                pageIdentity(fit)
                    .padding(.top, 31 * fit.scale)
                    .padding(.bottom, 24 * fit.scale)

                Spacer(minLength: 0)

                board(fit)
                    .frame(width: fit.boardWidth, height: fit.boardHeight)

            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Color(uiColor: Palette.board))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Are you sure you want to delete?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteCurrentPage(); selected = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the keyboard page along with all its contents or buttons.")
        }
        .sheet(isPresented: $showingSetup) { SetupView() }
        .sheet(isPresented: Binding(get: { selected != nil },
                                    set: { if !$0 { selected = nil } })) {
            if let index = selected {
                ButtonEditor(button: store.binding(at: index),
                             pages: store.pages,
                             currentPageID: store.currentPageID) { selected = nil }
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) { OnboardingView() }
        .onAppear {
            guard !onboardingSeen,
                  !ProcessInfo.processInfo.arguments.contains("-skipOnboarding") else { return }
            onboardingSeen = true
            showingOnboarding = true
        }
    }

    /// Glyph row and label row share a column width, so labels line up.
    private func actions(_ fit: HomeFit) -> some View {
        let column = 200 * fit.scale
        let pad = 18 * fit.scale
        return VStack(spacing: 14 * fit.scale) {
            HStack(spacing: 0) {
                ForEach(pageActions) { action in
                    Button(action: action.run) {
                        Image(systemName: action.symbol)
                            .font(.system(size: 58 * fit.scale, weight: .regular))
                            .frame(width: column, height: 92 * fit.scale)
                            .background {
                                if action.active {
                                    RoundedRectangle(cornerRadius: 24 * fit.scale,
                                                     style: .continuous)
                                        .fill(Color(uiColor: Palette.action))
                                        .frame(width: 124 * fit.scale, height: 92 * fit.scale)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!action.enabled)
                    .foregroundStyle(glyphColor(action))
                    .accessibilityLabel(action.title)
                    // Colour alone cannot carry state on a board somebody
                    // may not see in colour, or at all.
                    .accessibilityAddTraits(action.active ? [.isSelected] : [])
                }
            }
            .padding(pad)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: Palette.board))
                    .shadow(color: .black.opacity(0.14), radius: 24 * fit.scale, y: 6 * fit.scale)
            )

            HStack(spacing: 0) {
                ForEach(pageActions) { action in
                    Text(action.title)
                        .font(.system(size: 26 * fit.scale,
                                      weight: action.active ? .semibold : .regular))
                        .foregroundStyle(captionColor(action))
                        .frame(width: column)
                }
            }
            .padding(.horizontal, pad)
        }
    }

    private func glyphColor(_ action: PageAction) -> Color {
        if action.active { return .white }
        return action.enabled ? .primary : Color(.tertiaryLabel)
    }

    private func captionColor(_ action: PageAction) -> Color {
        if action.active { return Color(uiColor: Palette.action) }
        return action.enabled ? Color(uiColor: Palette.homeGlyph) : Color(.tertiaryLabel)
    }

    private var pageActions: [PageAction] {
        [
            PageAction(title: "Delete Page", symbol: "trash",
                       enabled: store.canDeleteCurrentPage) {
                confirmingDelete = true
            },
            PageAction(title: "Add New Page", symbol: "plus", enabled: true) {
                store.addPage()
                editing = true
            },
            PageAction(title: "Edit Page", symbol: "square.and.pencil",
                       enabled: store.canEditCurrentPage, active: editing) {
                editing.toggle()
                if !editing { selected = nil; focusName(false); level = .page }
            },
        ]
    }

    private func practiceField(_ fit: HomeFit) -> some View {
        VStack(alignment: .leading, spacing: 8 * fit.scale) {
            PracticeLine(composer: composer,
                         placeholder: "Tap a key from the keyboard.",
                         fontSize: 31 * fit.scale)
            Rectangle()
                .fill(Color(red: 1.0, green: 0.76, blue: 0.0))
                .frame(height: 3)
        }
    }

    @ViewBuilder
    private func pageIdentity(_ fit: HomeFit) -> some View {
        if editing {
            // Not a TextField: one would raise the system keyboard over the
            // board that exists to replace it. The name is typed on the
            // board, like everything else here, so this is a field-shaped
            // target that takes focus and lets the keys do the writing.
            Button {
                focusName(!namingFocused)
                if namingFocused { level = .letters }
            } label: {
                VStack(spacing: 4 * fit.scale) {
                    Text("Name of Page")
                        .font(.system(size: 23 * fit.scale))
                        .foregroundStyle(Color(uiColor: Palette.homeGlyph))
                    HStack(spacing: 3 * fit.scale) {
                        Text(store.currentName)
                            .font(.system(size: 24 * fit.scale, weight: .semibold))
                            .foregroundStyle(.primary)
                        if namingFocused {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(uiColor: Palette.action))
                                .frame(width: 3 * fit.scale, height: 28 * fit.scale)
                        }
                    }
                    .padding(.horizontal, 22 * fit.scale)
                    .frame(minWidth: 360 * fit.scale, minHeight: 56 * fit.scale)
                    .background(
                        RoundedRectangle(cornerRadius: 14 * fit.scale, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14 * fit.scale, style: .continuous)
                            .stroke(namingFocused
                                    ? Color(uiColor: Palette.action)
                                    : Color(uiColor: Palette.homeGlyph).opacity(0.5),
                                    lineWidth: namingFocused ? 3 : 1.5))
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Name of Page, \(store.currentName)")
            .accessibilityHint("Types on the board below")
            .accessibilityAddTraits(namingFocused ? [.isSelected] : [])
            .accessibilityIdentifier("pageNameField")
        } else {
            Menu {
                ForEach(store.pages) { page in
                    Button {
                        store.go(to: page.id)
                        selected = nil
                    } label: {
                        Label(page.name,
                              systemImage: page.id == store.currentPageID
                                  ? "checkmark" : "square.grid.2x2")
                    }
                }
                Divider()
                Button("Setup", systemImage: "gearshape") { showingSetup = true }
            } label: {
                VStack(spacing: 4 * fit.scale) {
                    Text("Name of Page")
                        .font(.system(size: 23 * fit.scale))
                        .foregroundStyle(Color(uiColor: Palette.homeGlyph))
                    Text(store.currentName)
                        .font(.system(size: 24 * fit.scale, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Name of Page, \(store.currentName)")
        }
    }

    // MARK: - The board, which is the keyboard's own

    private func board(_ fit: HomeFit) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: editing ? Palette.editingBoard : Palette.board))
                .shadow(color: .black.opacity(0.16), radius: 8, y: -2)
            // Not built while a sheet covers it. Nothing behind a modal is
            // reachable, and these keys carry the real keyboard's labels —
            // leaving them in the tree makes every query match twice.
            if !showingSetup && !showingOnboarding {
                PracticeBoard(level: level, pages: store.pages,
                              currentPage: store.currentPage, shifted: shifted,
                              editing: editing, selected: selected, onKey: press,
                              onEditCell: { selected = $0 })
            }
        }
    }

    /// The one way the name gains or loses focus, so a blank name can never
    /// escape by an route that forgot to check.
    private func focusName(_ on: Bool) {
        guard namingFocused != on else { return }
        if on { nameBeforeEdit = store.currentName }
        else { store.commitName(fallback: nameBeforeEdit) }
        namingFocused = on
    }

    /// Renaming a page, on the board rather than over it.
    ///
    /// Returns false for anything that is not text, so the edges still
    /// navigate mid-rename and the caller can drop focus.
    private func renameWith(_ action: KeyAction) -> Bool {
        switch action {
        case .char(let c):
            store.currentName += shifted ? c.uppercased() : c
            shifted = false
        case .shift:       shifted.toggle()
        case .space:       store.currentName += " "
        case .punct(let p): store.currentName += p
        case .delete:      store.currentName = String(store.currentName.dropLast())
        case .deleteWord, .clearAll: store.currentName = ""
        case .ret, .dismiss:
            focusName(false)
            level = .page
        default: return false
        }
        return true
    }

    /// What a key does here. The keyboard's own `commit` types into the
    /// document proxy and learns; this types into the practice line.
    private func press(_ action: KeyAction) {
        if namingFocused {
            if renameWith(action) { return }
            focusName(false)   // anything that is not text leaves the name
        }
        switch action {
        case .word(let w): composer.insertWord(w)
        case .char(let c):
            composer.insertCharacter(shifted ? c.uppercased() : c)
            shifted = false
        case .shift:       shifted.toggle()
        case .space:       composer.insert(" ")
        case .ret:         composer.insert("\n")
        case .delete:      composer.deleteBackward()
        case .deleteWord:  composer.deleteWord()
        case .clearAll:    composer.clear()
        case .cursorLeft:  composer.moveLeft()
        case .cursorRight: composer.moveRight()
        case .pageBack:    store.step(by: -1); level = .page; selected = nil
        case .pageForward: store.step(by: 1); level = .page; selected = nil
        case .punct(let p): composer.insertWord(p)
        case .home:        level = .page; store.goHome(); selected = nil
        case .toCategories: level = .categories; selected = nil
        case .toPage(let id): store.go(to: id); level = .page; selected = nil
        case .toLetters:   level = .letters
        case .toNumbers:   level = .numbers
        case .toWords:     level = .categories
        case .dismiss:     level = .page
        }
    }
}

enum PracticeLevel: Equatable {
    case page, categories, letters, numbers

    var isTyping: Bool { self == .letters || self == .numbers }
}

/// Fits the 1366 x 1024 reference design to the screen it actually got.
/// Keys stay square, so the chrome scales into what the board leaves; once
/// the chrome hits its floor the board gives up width instead of overflowing.
struct HomeFit {
    private static let referenceChrome: CGFloat = 442
    private static let minChromeScale: CGFloat = 0.62

    let scale: CGFloat
    let cell: CGFloat

    init(size: CGSize) {
        let inset = KeyboardFit.outerInset, gap = KeyboardFit.gap
        let widthCell = (size.width - inset * 2 - gap * 9) / 10
        let boardHeight = { (cell: CGFloat) in cell * 4 + gap * 3 + inset * 2 }

        let wanted = size.height - boardHeight(widthCell)
        let fitted = max(Self.minChromeScale, min(1, wanted / Self.referenceChrome))
        scale = fitted

        let budget = size.height - Self.referenceChrome * fitted
        cell = max(1, min(widthCell, (budget - inset * 2 - gap * 3) / 4))
    }

    var boardWidth: CGFloat { cell * 10 + KeyboardFit.gap * 9 + KeyboardFit.outerInset * 2 }
    var boardHeight: CGFloat { cell * 4 + KeyboardFit.gap * 3 + KeyboardFit.outerInset * 2 }
}

private struct PageAction: Identifiable {
    let title: String
    let symbol: String
    let enabled: Bool
    /// The action is currently on. Editing changes what every key on the
    /// board does, so it has to be visible without tapping anything to find
    /// out — and without reading, which is the whole premise here.
    var active = false
    let run: () -> Void

    var id: String { title }
}
