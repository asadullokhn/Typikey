import Foundation

/// One tile on the category level.
///
/// The built-in boards and the two the keyboard computes for itself
/// (Recents, Mine) are the same kind of thing here, because from the
/// editor's side they are: they occupy a cell, they have a name and a
/// symbol, and their order decides which page he finds them on. What
/// differs is whether they can be removed, and that is one flag rather
/// than two code paths.
struct BoardTile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var symbol: String
    /// Recents and Mine are computed by the keyboard from what he has
    /// actually used. Removing them would remove the mechanism rather than
    /// a page, so the editor does not offer it.
    var isRemovable: Bool
}

/// What the category level looks like, and the one place that decides it.
///
/// Stored in the App Group so the keyboard reads exactly what the app
/// wrote. Until somebody changes something there is nothing stored at all
/// and both sides fall back to the built-in vocabulary — so a fresh
/// install, a failed read and a revoked Full Access all behave the same
/// way, and that way is "the keyboard works". Nothing here is allowed to
/// be the reason he cannot say something.
///
/// Deliberately Foundation-only and free of any observation machinery:
/// this file compiles into the keyboard extension, which only ever reads.
/// The app owns the editing, and wraps this.
enum BoardLayout {
    static let storeKey = "boardOrder"

    /// The shipped arrangement. Recents first and Mine last, matching the
    /// order the keyboard builds them in — `allCategories()` puts usage at
    /// the front and his own words at the end, and the editor must not
    /// disagree with the board it is editing.
    static var builtIn: [BoardTile] {
        [BoardTile(id: "Recents", name: "Recents", symbol: "🕘", isRemovable: false)]
        + vocabulary.map { BoardTile(id: $0.name, name: $0.name,
                                     symbol: symbol(for: $0.name), isRemovable: true) }
        + [BoardTile(id: "Mine", name: "Mine", symbol: "🙋", isRemovable: false)]
    }

    /// The stored arrangement, repaired against what actually exists.
    ///
    /// A stored list that no longer matches the vocabulary is mended
    /// rather than rejected: tiles naming a board that is gone are
    /// dropped, and boards added since are appended. So shipping a new
    /// category never strands anyone on an old arrangement, and never
    /// throws away the one they made.
    static func load(from store: UserDefaults) -> [BoardTile] {
        let built = builtIn
        guard let data = store.data(forKey: storeKey),
              let stored = try? JSONDecoder().decode([BoardTile].self, from: data)
        else { return built }

        let known = Set(built.map(\.id))
        var repaired = stored.filter { known.contains($0.id) }
        let present = Set(repaired.map(\.id))
        repaired += built.filter { !present.contains($0.id) }
        return repaired
    }

    static func save(_ tiles: [BoardTile], to store: UserDefaults) {
        guard let data = try? JSONEncoder().encode(tiles) else { return }
        store.set(data, forKey: storeKey)
    }

    /// A stand-in until the design's line-art arrives. Keiko's tiles carry
    /// drawn symbols; those are licensed artwork and a decision of their
    /// own, so this keeps the layout honest without pretending the art is
    /// done.
    static func symbol(for category: String) -> String {
        switch category {
        case "Core":         return "⭐️"
        case "People":       return "👨‍👩‍👧‍👦"
        case "Actions":      return "🤲"
        case "Feelings":     return "😊"
        case "Food":         return "🍎"
        case "Places":       return "🏠"
        case "Art":          return "🖼️"
        case "Web":          return "🌐"
        case "Chat":         return "💬"
        case "Little words": return "🔤"
        default:             return "🔡"
        }
    }
}

// MARK: - Pages, as the editor sees them

/// One key on a page.
///
/// Three things decide what a key is, and Keiko's editor asks for exactly
/// those three: what it says, what it looks like, and where it goes. A key
/// with no destination writes its label; a key with one is a doorway.
struct BoardButton: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    /// A symbol identifier, not image data. The picture lives in the app;
    /// the keyboard is under a 30-80MB ceiling and cannot carry an asset
    /// library, so what crosses the App Group is a name.
    var image: String?
    /// The page this key opens, if it opens one.
    var destination: String?

    init(id: String = UUID().uuidString, label: String,
         image: String? = nil, destination: String? = nil) {
        self.id = id
        self.label = label
        self.image = image
        self.destination = destination
    }
}

/// A page of the keyboard, at the keyboard's own geometry.
///
/// `cells` is positional and fixed-length: index 0 is the top-left content
/// cell and every index maps to one place on the board, forever. An empty
/// cell is `nil` rather than absent, because a list that closed up behind a
/// deletion would slide every key after it — and a key that moves is a key
/// he has to find again (invariant 1).
struct KeyboardPage: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var cells: [BoardButton?]

    static let columns = 10
    static let rows = 4
    static var cellCount: Int { columns * rows }

    init(id: String, name: String, cells: [BoardButton?] = []) {
        self.id = id
        self.name = name
        self.cells = cells
        self.cells += Array(repeating: nil, count: max(0, Self.cellCount - self.cells.count))
    }
}

extension BoardLayout {
    static let pagesKey = "keyboardPages"

    /// The shipped boards, expressed as editable pages.
    ///
    /// Home first and named as the design names it. Each category becomes a
    /// page, and each of its words a key — which is what makes the built-in
    /// vocabulary a starting point rather than a wall.
    static var builtInPages: [KeyboardPage] {
        let home = KeyboardPage(
            id: "home", name: "Keyboard Home",
            cells: BoardPlan.homeSelection.map { BoardButton(id: "home.\($0)", label: $0) })
        return [home] + vocabulary.map { category in
            KeyboardPage(id: category.name, name: category.name,
                         cells: category.words.map {
                             BoardButton(id: "\(category.name).\($0.text)",
                                         label: $0.text, image: $0.emoji)
                         })
        }
    }

    static func loadPages(from store: UserDefaults) -> [KeyboardPage] {
        guard let data = store.data(forKey: pagesKey),
              let stored = try? JSONDecoder().decode([KeyboardPage].self, from: data),
              !stored.isEmpty
        else { return builtInPages }
        return stored
    }

    static func savePages(_ pages: [KeyboardPage], to store: UserDefaults) {
        guard let data = try? JSONEncoder().encode(pages) else { return }
        store.set(data, forKey: pagesKey)
    }
}
