import Foundation

/// The practice line's text and caret. Not a text field: a real one would
/// raise the system keyboard over the board it is demonstrating.
struct PracticeComposer: Equatable {
    private(set) var text = ""
    private(set) var caret = 0

    private static let closing: Set<Character> = [".", ",", "?", "!", ";", ":", "'"]

    var isEmpty: Bool { text.isEmpty }

    var before: String { String(text.prefix(caret)) }
    var after: String { String(text.dropFirst(caret)) }

    mutating func insertWord(_ word: String) {
        if word.count == 1, let c = word.first, Self.closing.contains(c) {
            trimTrailingSpace()
        }
        if WordJoin.leads(word) { trimTrailingSpace() }
        insert(WordJoin.trails(word) ? word : word + " ")
    }

    mutating func insertCharacter(_ character: String) {
        if character.count == 1, let c = character.first, Self.closing.contains(c) {
            trimTrailingSpace()
        }
        insert(character)
    }

    mutating func insert(_ string: String) {
        text.insert(contentsOf: string, at: index(caret))
        caret += string.count
    }

    mutating func deleteBackward() {
        guard caret > 0 else { return }
        text.remove(at: index(caret - 1))
        caret -= 1
    }

    mutating func deleteWord() {
        var removed = 0
        while caret - removed > 0, isSpace(at: caret - removed - 1) { removed += 1 }
        while caret - removed > 0, !isSpace(at: caret - removed - 1) { removed += 1 }
        guard removed > 0 else { return }
        let start = index(caret - removed)
        text.removeSubrange(start..<index(caret))
        caret -= removed
    }

    mutating func clear() {
        text = ""
        caret = 0
    }

    mutating func moveLeft() { caret = max(0, caret - 1) }
    mutating func moveRight() { caret = min(text.count, caret + 1) }

    private mutating func trimTrailingSpace() {
        guard caret > 0, isSpace(at: caret - 1) else { return }
        text.remove(at: index(caret - 1))
        caret -= 1
    }

    private func isSpace(at offset: Int) -> Bool {
        text[index(offset)] == " "
    }

    private func index(_ offset: Int) -> String.Index {
        text.index(text.startIndex, offsetBy: min(max(0, offset), text.count))
    }
}
