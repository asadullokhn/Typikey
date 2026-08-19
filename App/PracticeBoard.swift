import SwiftUI

/// The keyboard's own board, hosted in the app.
///
/// Same view, same layout, same explore-then-commit: sliding highlights and
/// lifting commits, every point maps to the nearest key, and a repeated key
/// is ignored for half a second. Only what a key *does* differs — here it
/// types into a composer instead of a text document proxy.
struct PracticeBoard: UIViewRepresentable {
    let level: PracticeLevel
    let pages: [KeyboardPage]
    let currentPage: KeyboardPage?
    let shifted: Bool
    let editing: Bool
    /// The content cell whose editor is open, so the board can ring it.
    let selected: Int?
    let onKey: (KeyAction) -> Void
    /// A content cell tapped while editing. Editing never types.
    let onEditCell: (Int) -> Void

    func makeUIView(context: Context) -> BoardGridView {
        let grid = BoardGridView()
        grid.isMultipleTouchEnabled = false
        grid.backgroundColor = .clear
        grid.context.word = { vocabIndex[$0] ?? vocabIndex[$0.lowercased()] }
        return grid
    }

    func updateUIView(_ grid: BoardGridView, context: Context) {
        grid.onCommit = { key in
            // The edges stay live while editing — that is how you reach the
            // page you want to change. Only a page's own cells become
            // targets: the letters are the keyboard's, not hers, and a tap
            // on "a" is a letter even mid-edit.
            if editing, level == .page, let index = Self.contentIndex(of: key) {
                onEditCell(index)
            } else {
                onKey(key.action)
            }
        }
        grid.context.shifted = shifted
        grid.context.isTypingLevel = level.isTyping
        grid.geometry = BoardGridView.Geometry(
            referenceColumns: 10,
            contentColumns: level.isTyping ? TypingLayout.columns : KeyboardPage.columns,
            contentRowCount: KeyboardPage.rows,
            isCompact: false,
            bottomInset: KeyboardFit.outerInset)
        grid.setKeys(placements)
        grid.selectedKey = selected.flatMap {
            grid.keyIndex(row: $0 / KeyboardPage.columns, col: $0 % KeyboardPage.columns + 1)
        }
    }

    /// Which cell of the page a key belongs to, or nil for the keyboard's own
    /// furniture — the two edge columns and the cursor keys, which belong to
    /// the keyboard rather than to the page and are not hers to move.
    private static func contentIndex(of key: BoardGridView.Key) -> Int? {
        let column = key.col - 1
        guard (0..<KeyboardPage.columns).contains(column) else { return nil }
        let index = key.row * KeyboardPage.columns + column
        return BoardFrame.stepAction(atContentIndex: index) == nil ? index : nil
    }

    private var placements: [(cell: ContentCell, row: Int, col: Int)] {
        var out: [(ContentCell, Int, Int)] = []
        for (row, cell) in BoardFrame.leftColumn.enumerated() { out.append((cell, row, 0)) }

        let columns = level.isTyping ? TypingLayout.columns : KeyboardPage.columns
        let right = columns + 1
        out.append((BoardFrame.rightTop(level: level == .letters ? .letters : .home), 0, right))
        out.append((BoardFrame.rightEnter(label: "Enter"), 1, right))
        out.append((BoardFrame.rightDismiss, 3, right))

        for (row, cells) in contentRows.enumerated() {
            for (column, cell) in cells.enumerated() where cell != nil {
                out.append((cell!, row, column + 1))
            }
        }
        return out
    }

    private var contentRows: [[ContentCell?]] {
        switch level {
        case .letters: return TypingLayout.letters.map { $0.map(cell) }
        case .numbers: return TypingLayout.numbers.map { $0.map(cell) }
        case .categories: return categoryRows
        case .page: return pageRows
        }
    }

    private func cell(_ typed: TypingLayout.Cell?) -> ContentCell? {
        guard let typed else { return nil }
        let action: KeyAction
        switch typed.key {
        case .char(let c):  action = .char(c)
        case .shift:        action = .shift
        case .space:        action = .space
        case .delete:       action = .delete
        case .cursorLeft:   action = .cursorLeft
        case .cursorRight:  action = .cursorRight
        case .toLetters:    action = .toLetters
        case .toNumbers:    action = .toNumbers
        }
        return ContentCell(action, typed.label, colSpan: typed.colSpan)
    }

    private var pageRows: [[ContentCell?]] {
        var rows = [[ContentCell?]](
            repeating: [ContentCell?](repeating: nil, count: KeyboardPage.columns),
            count: KeyboardPage.rows)
        for index in 0..<(KeyboardPage.rows * KeyboardPage.columns) {
            let row = index / KeyboardPage.columns, column = index % KeyboardPage.columns
            if let step = BoardFrame.stepAction(atContentIndex: index) {
                rows[row][column] = ContentCell(step, BoardFrame.stepLabel(for: step))
            } else if let button = currentPage?.cells[safe: index] ?? nil,
                      !button.label.isEmpty {
                // A key with a destination is a doorway, here as on the
                // keyboard — it opens the page rather than writing its name.
                rows[row][column] = button.destination.map {
                    ContentCell(.toPage($0), button.label)
                } ?? ContentCell(.word(button.label), button.label)
            } else if editing {
                rows[row][column] = ContentCell(.word(""), "")
            }
        }
        return rows
    }

    private var categoryRows: [[ContentCell?]] {
        var rows = [[ContentCell?]](
            repeating: [ContentCell?](repeating: nil, count: KeyboardPage.columns),
            count: KeyboardPage.rows)
        let span = 2, perRow = KeyboardPage.columns / span
        for (index, page) in pages.filter({ $0.id != "home" })
            .prefix(perRow * KeyboardPage.rows).enumerated() {
            rows[index / perRow][index % perRow * span] =
                ContentCell(.toPage(page.id), page.name, colSpan: span)
        }
        return rows
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
