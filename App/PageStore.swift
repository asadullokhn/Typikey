import SwiftUI
import Combine

/// The pages the editor works on, and the one place that writes them.
///
/// Only the app edits; the keyboard only reads, which is why the model and
/// the file access live in Shared/BoardLayout and only the observation
/// lives here. Every change writes through immediately — Keiko's design
/// has no save button, and adding one would mean a page could be arranged
/// and then lost.
@MainActor
final class PageStore: ObservableObject {
    @Published private(set) var pages: [KeyboardPage] = []
    @Published var currentIndex = 0
    /// What the keyboard last typed into the app's practice field, so the
    /// header shows the real thing rather than a mock-up.
    @Published private(set) var previewText = ""

    private let store: UserDefaults

    init(store: UserDefaults = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard) {
        self.store = store
        pages = BoardLayout.loadPages(from: store)
    }

    /// Whether anything written here can actually reach the keyboard.
    ///
    /// The keyboard sets this the first time it runs with Full Access; without
    /// the grant it reads its own sandbox and never sees the shared container
    /// at all, so an edit made here would simply not happen.
    var keyboardCanSeeEdits: Bool { store.bool(forKey: ScreenWords.keyboardAccessKey) }

    var currentPageID: String { pages.indices.contains(currentIndex) ? pages[currentIndex].id : "" }

    var currentName: String {
        get { pages.indices.contains(currentIndex) ? pages[currentIndex].name : "" }
        set {
            guard pages.indices.contains(currentIndex) else { return }
            pages[currentIndex].name = newValue
            save()
        }
    }

    /// Home cannot be deleted. Every other page is reachable only through
    /// a key that points at it, but home is where the keyboard opens — a
    /// board with no home is a board with no way back.
    var canDeleteCurrentPage: Bool { currentPageID != "home" }

    func button(at index: Int) -> BoardButton? {
        guard pages.indices.contains(currentIndex),
              pages[currentIndex].cells.indices.contains(index) else { return nil }
        return pages[currentIndex].cells[index]
    }

    /// Editing an empty cell creates the key there, so a blank space is
    /// somewhere to put something rather than something to fix first.
    func binding(at index: Int) -> Binding<BoardButton> {
        Binding(
            get: { self.button(at: index) ?? BoardButton(label: "") },
            set: { newValue in
                guard self.pages.indices.contains(self.currentIndex),
                      self.pages[self.currentIndex].cells.indices.contains(index) else { return }
                // A key emptied of everything is an empty cell again, not a
                // blank key sitting in the way.
                let emptied = newValue.label.isEmpty && newValue.image == nil
                    && newValue.destination == nil
                self.pages[self.currentIndex].cells[index] = emptied ? nil : newValue
                self.save()
            })
    }

    func addPage() {
        var n = pages.count
        var id = "page.\(n)"
        while pages.contains(where: { $0.id == id }) { n += 1; id = "page.\(n)" }
        pages.append(KeyboardPage(id: id, name: "New Page"))
        currentIndex = pages.count - 1
        save()
    }

    func deleteCurrentPage() {
        guard canDeleteCurrentPage, pages.indices.contains(currentIndex) else { return }
        let gone = pages[currentIndex].id
        pages.remove(at: currentIndex)
        // A key pointing at a page that no longer exists would be a key
        // that does nothing, which is worse than a key that writes its
        // label — so the doorway becomes an ordinary word again.
        for page in pages.indices {
            for cell in pages[page].cells.indices
            where pages[page].cells[cell]?.destination == gone {
                pages[page].cells[cell]?.destination = nil
            }
        }
        currentIndex = min(currentIndex, pages.count - 1)
        save()
    }

    private func save() { BoardLayout.savePages(pages, to: store) }

    // MARK: The keyboard's fixed furniture, which the editor shows and does not change

    static let pinned = ["Home", "Clear", "Delete\nword", "sf:globe"]

    /// The controls the design places inside the content grid. They are
    /// drawn so the editor's geometry matches the keyboard's exactly, and
    /// they are not editable: they belong to the keyboard, not the page.
    static func fixedControl(row: Int, column: Int) -> String? {
        switch (row, column) {
        case (0, 0): return "sf:square.grid.2x2.fill"
        case (0, 1): return "ABC"
        case (1, 8), (1, 9): return column == 8 ? "Enter" : ""
        case (3, 8): return "sf:keyboard.chevron.compact.down"
        case (3, 9): return "sf:arrow.right"
        default: return nil
        }
    }

    static func tint(for control: String) -> Color {
        switch control {
        case "Enter", "": return Color(red: 0.80, green: 0.87, blue: 0.96)
        case "ABC", "sf:square.grid.2x2.fill",
             "sf:keyboard.chevron.compact.down", "sf:arrow.right":
            return Color(.systemBackground)
        default: return Color(.systemGray2)
        }
    }

    /// The Fitzgerald key, matched to the keyboard's own palette so the
    /// editor and the board never disagree about what colour a word is.
    static func tint(forWord word: String?) -> Color {
        guard let word, !word.isEmpty else { return Color(.systemGray6) }
        guard let entry = vocabIndex[word] ?? vocabIndex[word.lowercased()] else {
            return Color(red: 0.96, green: 0.95, blue: 0.91)
        }
        switch entry.wordClass {
        case .pronoun:    return Color(red: 0.98, green: 0.96, blue: 0.72)
        case .verb:       return Color(red: 0.80, green: 0.91, blue: 0.72)
        case .descriptor: return Color(red: 0.86, green: 0.93, blue: 0.98)
        case .noun:       return Color(red: 1.00, green: 0.87, blue: 0.72)
        case .social:     return Color(red: 0.99, green: 0.85, blue: 0.91)
        case .question:   return Color(red: 0.90, green: 0.85, blue: 0.98)
        case .function:   return Color(red: 0.96, green: 0.95, blue: 0.91)
        case .punct:      return .white
        }
    }
}
