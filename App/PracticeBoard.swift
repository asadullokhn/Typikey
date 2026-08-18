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
    let onKey: (KeyAction) -> Void

    func makeUIView(context: Context) -> BoardGridView {
        let grid = BoardGridView()
        grid.isMultipleTouchEnabled = false
        grid.backgroundColor = .clear
        grid.context.word = { vocabIndex[$0] ?? vocabIndex[$0.lowercased()] }
        return grid
    }

    func updateUIView(_ grid: BoardGridView, context: Context) {
        grid.onCommit = onKey
        grid.context.shifted = shifted
        grid.context.isTypingLevel = level.isTyping
        grid.geometry = BoardGridView.Geometry(
            referenceColumns: 10,
            contentColumns: level.isTyping ? TypingLayout.columns : KeyboardPage.columns,
            contentRowCount: KeyboardPage.rows,
            isCompact: false,
            bottomInset: KeyboardFit.outerInset)
        grid.setKeys(placements)
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
            if let cursor = BoardFrame.cursorAction(atContentIndex: index) {
                rows[row][column] = ContentCell(
                    cursor, cursor == .cursorLeft ? "Cursor left" : "Cursor right")
            } else if let button = currentPage?.cells[safe: index] ?? nil, !button.label.isEmpty {
                rows[row][column] = ContentCell(.word(button.label), button.label)
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
