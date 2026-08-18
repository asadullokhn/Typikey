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

    init(store: UserDefaults = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard) {
        self.store = store
        pages = Self.withHome(BoardLayout.loadPages(from: store))
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

    private func save() {
        BoardLayout.savePages(pages, to: store)
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
