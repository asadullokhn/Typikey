import Foundation

/// What a key does, and which board it belongs to.
///
/// Shared because both the keyboard extension and the app's practice board
/// draw the same keys; only what they type into differs.
enum KeyAction: Equatable {
    case word(String)
    case punct(String)
    case char(String)
    case shift
    case delete
    case deleteWord
    /// Two-tap armed: the one irreversible key.
    case clearAll
    case cursorLeft
    case cursorRight
    case home
    case toCategories
    /// Index into `allCategories()`.
    case toWords(Int)
    /// A page built in the app, by id.
    case toPage(String)
    case toLetters
    case toNumbers
    case space
    case ret
    case dismiss
}

enum BoardLevel: Equatable {
    case home, categories, letters, numbers
    case words(Int)
    case page(String)
}

/// A content cell, which may span several grid slots — a wide space bar, a
/// double-height Enter.
struct ContentCell: Equatable {
    let action: KeyAction
    let label: String
    let colSpan: Int
    let rowSpan: Int

    init(_ action: KeyAction, _ label: String, colSpan: Int = 1, rowSpan: Int = 1) {
        self.action = action
        self.label = label
        self.colSpan = colSpan
        self.rowSpan = rowSpan
    }
}

/// The board's fixed furniture, defined once.
///
/// Four controls pin the left edge and three the right, on every level.
/// The keyboard and the app both draw these, and defining them twice is how
/// the two boards drift apart.
enum BoardFrame {
    static let leftColumn: [ContentCell] = [
        ContentCell(.home, "Home"),
        ContentCell(.toCategories, "Categories"),
        ContentCell(.clearAll, "Clear"),
        ContentCell(.deleteWord, "Delete\nword"),
    ]

    /// ABC on a word board, 123 once you are already on abc.
    static func rightTop(level: BoardLevel) -> ContentCell {
        level == .letters
            ? ContentCell(.toNumbers, "123")
            : ContentCell(.toLetters, "ABC")
    }

    static func rightEnter(label: String) -> ContentCell {
        ContentCell(.ret, label, rowSpan: 2)
    }

    static let rightDismiss = ContentCell(.dismiss, "Hide keyboard")

    /// The two bottom corners of the editable area stay cursor keys.
    static let cursorCells: Set<Int> = [24, 31]

    static func cursorAction(atContentIndex index: Int) -> KeyAction? {
        switch index {
        case 24: return .cursorLeft
        case 31: return .cursorRight
        default: return nil
        }
    }

    /// The controls the design draws as a glyph rather than a word.
    static func symbolName(for action: KeyAction) -> String? {
        switch action {
        case .home: return "house.fill"
        case .toCategories: return "square.grid.2x2.fill"
        case .dismiss: return "keyboard.chevron.compact.down"
        case .cursorRight: return "arrow.right"
        case .cursorLeft: return "arrow.left"
        default: return nil
        }
    }
}
