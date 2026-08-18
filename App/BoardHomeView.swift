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
                    // Behind a sheet the board is unreachable, and its keys
                    // carry the same labels as the real keyboard's.
                    .accessibilityElement(children: showingSetup || showingOnboarding
                                          ? .ignore : .contain)
                    .accessibilityHidden(showingSetup || showingOnboarding)
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
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!action.enabled)
                    .foregroundStyle(action.enabled ? Color.primary : Color(.tertiaryLabel))
                    .accessibilityLabel(action.title)
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
                        .font(.system(size: 26 * fit.scale))
                        .foregroundStyle(action.enabled ? Color(uiColor: Palette.homeGlyph) : Color(.tertiaryLabel))
                        .frame(width: column)
                }
            }
            .padding(.horizontal, pad)
        }
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
                       enabled: store.canEditCurrentPage) {
                editing.toggle()
                if !editing { selected = nil }
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
            VStack(spacing: 4 * fit.scale) {
                Text("Name of Page")
                    .font(.system(size: 23 * fit.scale))
                    .foregroundStyle(Color(uiColor: Palette.homeGlyph))
                TextField("Name of Page", text: $store.currentName)
                    .font(.system(size: 24 * fit.scale, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 360 * fit.scale)
            }
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

    // MARK: - The board, which types

    /// Eight content columns on a word board, ten on abc and 123 — the
    /// keyboard's own rule.
    private var contentColumns: Int {
        level.isTyping ? TypingLayout.columns : KeyboardPage.columns
    }

    private func board(_ fit: HomeFit) -> some View {
        let metrics = BoardMetrics(cell: fit.cell, contentColumns: contentColumns)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: Palette.board))
                .shadow(color: .black.opacity(0.16), radius: 8, y: -2)

            ForEach(0..<KeyboardPage.rows, id: \.self) { row in
                let cell = BoardFrame.leftColumn[row]
                edgeKey(BoardFrame.symbolName(for: cell.action).map { "sf:\($0)" } ?? cell.label,
                        name: leftName(row),
                        row: row, left: true, metrics) { leftAction(row) }
            }

            switch level {
            case .page: pageGrid(metrics)
            case .categories: categoriesGrid(metrics)
            case .letters, .numbers: typingGrid(metrics)
            }

            let top = BoardFrame.rightTop(level: level == .letters ? .letters : .home)
            edgeKey(top.label, name: top.label, row: 0, metrics) {
                level = level == .letters ? .numbers : .letters
            }
            edgeKey("Enter", name: "Enter", row: 1, rowSpan: 2, metrics) {
                composer.insert("\n")
            }
            edgeKey("sf:keyboard.chevron.compact.down",
                    name: BoardFrame.rightDismiss.label, row: 3, metrics) { level = .page }
        }
    }

    private func edgeKey(_ label: String, name: String, row: Int, rowSpan: Int = 1,
                         left: Bool = false, _ metrics: BoardMetrics,
                         action: @escaping () -> Void) -> some View {
        ControlKey(label: label, tint: PageStore.tint(for: label),
                   accessibilityName: name, action: action)
            .frame(width: metrics.cell,
                   height: metrics.cell * CGFloat(rowSpan)
                           + metrics.spacing * CGFloat(rowSpan - 1))
            .position(metrics.edgeCenter(left: left, row: row, rowSpan: rowSpan))
    }

    private func pageGrid(_ metrics: BoardMetrics) -> some View {
        ForEach(0..<KeyboardPage.rows, id: \.self) { row in
            ForEach(0..<KeyboardPage.columns, id: \.self) { column in
                cell(row: row, column: column)
                    .frame(width: metrics.contentCell, height: metrics.cell)
                    .position(metrics.contentCenter(column: column, row: row))
            }
        }
    }

    /// Every page the app knows, as doorways — the keyboard's categories
    /// level, plus whatever pages have been built here.
    private func categoriesGrid(_ metrics: BoardMetrics) -> some View {
        let pages = store.pages.filter { $0.id != "home" }
        let span = 2
        let perRow = KeyboardPage.columns / span
        return ForEach(Array(pages.prefix(perRow * KeyboardPage.rows).enumerated()),
                       id: \.element.id) { index, page in
            ControlKey(label: page.name, tint: Palette.navigate, accessibilityName: page.name) {
                store.go(to: page.id)
                level = .page
                selected = nil
            }
            .frame(width: metrics.contentCell * CGFloat(span) + metrics.spacing,
                   height: metrics.cell)
            .position(metrics.contentCenter(column: index % perRow * span,
                                            row: index / perRow, colSpan: span))
        }
    }

    private func typingGrid(_ metrics: BoardMetrics) -> some View {
        let rows = level == .letters ? TypingLayout.letters : TypingLayout.numbers
        return ForEach(Array(rows.enumerated()), id: \.offset) { row, cells in
            ForEach(Array(cells.enumerated()), id: \.offset) { column, cell in
                if let cell {
                    typingKey(cell)
                        .frame(width: metrics.contentCell * CGFloat(cell.colSpan)
                                      + metrics.spacing * CGFloat(cell.colSpan - 1),
                               height: metrics.cell)
                        .position(metrics.contentCenter(column: column, row: row,
                                                        colSpan: cell.colSpan))
                }
            }
        }
    }

    @ViewBuilder
    private func typingKey(_ cell: TypingLayout.Cell) -> some View {
        let label: String = {
            switch cell.key {
            case .cursorLeft: return "sf:arrow.left"
            case .cursorRight: return "sf:arrow.right"
            case .char(let c): return shifted ? c.uppercased() : c
            default: return cell.label
            }
        }()
        ControlKey(label: label, tint: typingTint(cell.key),
                   accessibilityName: cell.label) {
            switch cell.key {
            case .char(let c):
                composer.insertCharacter(shifted ? c.uppercased() : c)
                shifted = false
            case .shift:       shifted.toggle()
            case .space:       composer.insert(" ")
            case .delete:      composer.deleteBackward()
            case .cursorLeft:  composer.moveLeft()
            case .cursorRight: composer.moveRight()
            case .toLetters:   level = .letters
            case .toNumbers:   level = .numbers
            }
        }
    }

    private func typingTint(_ key: TypingLayout.Key) -> UIColor {
        switch key {
        case .char, .space: return Palette.paper
        case .delete: return Palette.erase
        default: return Palette.navigate
        }
    }

    private func leftName(_ row: Int) -> String { Self.leftEdgeNames[row] }

    private func leftAction(_ row: Int) {
        switch row {
        case 0: level = .page; store.goHome(); selected = nil
        // Categories opens the list of boards, as it does on the keyboard —
        // it used to jump straight past it into Core.
        case 1: level = .categories; selected = nil
        case 2: composer.clear()
        default: composer.deleteWord()
        }
    }

    private static let leftEdgeNames = ["Home", "Categories", "Clear", "Delete word"]

    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        let index = row * KeyboardPage.columns + column
        if let fixed = PageStore.fixedControl(row: row, column: column) {
            ControlKey(label: fixed, tint: PageStore.tint(for: fixed),
                       accessibilityName: fixed == "sf:arrow.left" ? "Left" : "Right") {
                if fixed == "sf:arrow.left" { composer.moveLeft() } else { composer.moveRight() }
            }
        } else {
            ButtonKey(button: store.button(at: index),
                      editing: editing,
                      isSelected: selected == index) {
                if editing {
                    selected = selected == index ? nil : index
                } else if let destination = store.button(at: index)?.destination {
                    store.go(to: destination)
                } else if let word = store.button(at: index)?.label, !word.isEmpty {
                    composer.insertWord(word)
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

enum PracticeLevel: Equatable {
    case page, categories, letters, numbers

    var isTyping: Bool { self == .letters || self == .numbers }
}

/// Invariant 9: the pinned edges keep the word board's cell width on every
/// level, so they never move. Content columns divide what is left, which is
/// how abc holds ten columns without resizing the tray.
struct BoardMetrics {
    static let spacing: CGFloat = 8
    static let inset: CGFloat = 12

    let spacing = Self.spacing
    let inset = Self.inset
    /// Edge column width, and the row height on every level.
    let cell: CGFloat
    let contentCell: CGFloat
    private let contentLeft: CGFloat
    private let rightEdgeX: CGFloat

    init(cell: CGFloat, contentColumns: Int) {
        self.cell = cell
        // The tray is sized for the word board: two edges plus eight.
        let width = cell * 10 + Self.spacing * 9 + Self.inset * 2
        contentLeft = Self.inset + cell + Self.spacing
        rightEdgeX = width - Self.inset - cell
        let available = rightEdgeX - Self.spacing - contentLeft
        contentCell = max(1, (available - Self.spacing * CGFloat(contentColumns - 1))
                              / CGFloat(contentColumns))
    }

    private func y(row: Int, rowSpan: Int) -> CGFloat {
        inset + (cell * CGFloat(rowSpan) + spacing * CGFloat(rowSpan - 1)) / 2
            + CGFloat(row) * (cell + spacing)
    }

    func edgeCenter(left: Bool, row: Int, rowSpan: Int = 1) -> CGPoint {
        CGPoint(x: (left ? inset : rightEdgeX) + cell / 2, y: y(row: row, rowSpan: rowSpan))
    }

    func contentCenter(column: Int, row: Int, colSpan: Int = 1) -> CGPoint {
        let span = contentCell * CGFloat(colSpan) + spacing * CGFloat(colSpan - 1)
        return CGPoint(x: contentLeft + CGFloat(column) * (contentCell + spacing) + span / 2,
                       y: y(row: row, rowSpan: 1))
    }
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
        let inset = BoardMetrics.inset, gap = BoardMetrics.spacing
        let widthCell = (size.width - inset * 2 - gap * 9) / 10
        let boardHeight = { (cell: CGFloat) in cell * 4 + gap * 3 + inset * 2 }

        let wanted = size.height - boardHeight(widthCell)
        let fitted = max(Self.minChromeScale, min(1, wanted / Self.referenceChrome))
        scale = fitted

        let budget = size.height - Self.referenceChrome * fitted
        cell = max(1, min(widthCell, (budget - inset * 2 - gap * 3) / 4))
    }

    var boardWidth: CGFloat { cell * 10 + BoardMetrics.spacing * 9 + BoardMetrics.inset * 2 }
    var boardHeight: CGFloat { cell * 4 + BoardMetrics.spacing * 3 + BoardMetrics.inset * 2 }
}

private struct PageAction: Identifiable {
    let title: String
    let symbol: String
    let enabled: Bool
    let run: () -> Void

    var id: String { title }
}
