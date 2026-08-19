import SwiftUI
import UIKit
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

    private let store: UserDefaults

    private var resetObserver: NSObjectProtocol?

    init(store: UserDefaults = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard) {
        self.store = store
        pages = Self.withHome(BoardLayout.loadPages(from: store))
        // A reset that leaves the editor showing boards which no longer
        // exist anywhere is a reset that looks like it failed.
        resetObserver = NotificationCenter.default.addObserver(
            forName: FactoryReset.didReset, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            }
    }

    deinit {
        if let resetObserver { NotificationCenter.default.removeObserver(resetObserver) }
    }

    func reload() {
        pages = Self.withHome(BoardLayout.loadPages(from: store))
        currentIndex = 0
    }

    /// Add the shipped home page until the user saves an edited copy.
    private static func withHome(_ pages: [KeyboardPage]) -> [KeyboardPage] {
        guard !pages.contains(where: { $0.id == homeID }),
              let home = BoardLayout.builtInPages.first(where: { $0.id == homeID })
        else { return pages }
        return [home] + pages
    }

    private static let homeID = "home"

    var currentPage: KeyboardPage? {
        pages.indices.contains(currentIndex) ? pages[currentIndex] : nil
    }

    var currentPageID: String { currentPage?.id ?? "" }

    var currentName: String {
        get { pages.indices.contains(currentIndex) ? pages[currentIndex].name : "" }
        set {
            guard pages.indices.contains(currentIndex) else { return }
            pages[currentIndex].name = newValue
            save()
        }
    }

    /// Settles the name once somebody stops typing it.
    ///
    /// It is allowed to be empty while being typed — clearing it is how you
    /// replace it — but a page with no name is one nobody can pick out of
    /// the menu, so a blank one goes back to what it was called before.
    func commitName(fallback: String) {
        guard pages.indices.contains(currentIndex) else { return }
        let typed = pages[currentIndex].name.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let settled = typed.isEmpty ? (previous.isEmpty ? "New Page" : previous) : typed
        guard settled != pages[currentIndex].name else { return }
        pages[currentIndex].name = settled
        save()
    }

    /// Home cannot be deleted. Every other page is reachable only through
    /// a key that points at it, but home is where the keyboard opens — a
    /// board with no home is a board with no way back.
    var canDeleteCurrentPage: Bool { currentPageID != Self.homeID }

    var canEditCurrentPage: Bool { pages.indices.contains(currentIndex) }

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
                self.pages[self.currentIndex].arranged = true
                self.save()
            })
    }

    /// Move around the boards the way the keyboard does — through the keys
    /// themselves. A key that opens a page here opens it there, and Home
    /// comes back, so there is one set of directions to learn rather than
    /// two. Without this, adding a page strands you on it.
    func go(to id: String) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        currentIndex = index
    }

    func goHome() { go(to: Self.homeID) }

    /// One board along, wrapping. The two bottom corners of every board walk
    /// this list, so every page is reachable without going home first.
    func step(by delta: Int) {
        guard !pages.isEmpty else { return }
        currentIndex = ((currentIndex + delta) % pages.count + pages.count) % pages.count
    }

    func addPage() {
        var n = pages.count
        var id = "page.\(n)"
        while pages.contains(where: { $0.id == id }) { n += 1; id = "page.\(n)" }
        pages.append(KeyboardPage(id: id, name: "New Page", arranged: true))
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

    private func save() {
        // `withHome` hands the editor the shipped home so there is something
        // to arrange, and any edit anywhere writes the whole list. Writing an
        // untouched home would freeze the keyboard's home board: a stored
        // page opts out of the reshaping that moves words to the spare cells.
        BoardLayout.savePages(
            pages.filter { $0.id != Self.homeID || BoardLayout.isEdited($0) },
            to: store)
    }

    // MARK: The keyboard's fixed furniture, which the editor shows and does not change

    /// The controls the design places inside the content grid. They are
    /// drawn so the editor's geometry matches the keyboard's exactly, and
    /// they are not editable: they belong to the keyboard, not the page.
    static func fixedControl(row: Int, column: Int) -> String? {
        switch (row, column) {
        case (3, 0): return "sf:arrow.left"
        case (3, KeyboardPage.columns - 1): return "sf:arrow.right"
        default: return nil
        }
    }

    /// The same roles the keyboard paints by, from the same `Palette`.
    static func tint(for control: String) -> UIColor {
        switch control {
        case "Enter": return Palette.commit
        case "Clear", "Delete\nword": return Palette.erase
        // Home has no card on the keyboard: it sits on the tray itself.
        case "sf:house.fill": return Palette.board
        default: return Palette.navigate
        }
    }

    /// The Fitzgerald key, from the keyboard's own palette so the editor and
    /// the board never disagree about what colour a word is.
    static func tint(forWord word: String?) -> UIColor {
        guard let word, !word.isEmpty else { return .systemGray6 }
        guard let entry = vocabIndex[word] ?? vocabIndex[word.lowercased()]
        else { return Palette.function }
        return Palette.color(for: entry.wordClass)
    }
}
