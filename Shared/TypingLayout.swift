import Foundation

/// The abc and 123 boards as data, mapped by the keyboard onto `KeyAction`
/// and by the app onto its composer. Neither owns the layout, so they cannot
/// drift.
enum TypingLayout {
    enum Key: Equatable {
        case char(String)
        case shift
        case space
        case delete
        case cursorLeft
        case cursorRight
        case toLetters
        case toNumbers
    }

    struct Cell: Equatable {
        let key: Key
        let label: String
        let colSpan: Int

        init(_ key: Key, _ label: String, colSpan: Int = 1) {
            self.key = key
            self.label = label
            self.colSpan = colSpan
        }
    }

    static let columns = 10

    static var letters: [[Cell?]] {
        rows(
            "qwertyuiop".map { Cell(.char(String($0)), String($0)) },
            "asdfghjkl".map { Cell(.char(String($0)), String($0)) } + [Cell(.shift, "⇧")],
            "zxcvbnm".map { Cell(.char(String($0)), String($0)) }
                + [",", ".", "?"].map { Cell(.char($0), $0) })
    }

    static var numbers: [[Cell?]] {
        rows(
            "1234567890".map { Cell(.char(String($0)), String($0)) },
            ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { Cell(.char($0), $0) },
            [".", ",", "?", "!", "'"].map { Cell(.char($0), $0) })
    }

    private static func rows(_ a: [Cell], _ b: [Cell], _ c: [Cell]) -> [[Cell?]] {
        var third: [Cell?] = c
        third += Array(repeating: nil, count: max(0, columns - third.count))
        return [a, b, third, bottomRow]
    }

    /// The board switch lives on the pinned right edge (`BoardFrame.rightTop`)
    /// and used to be repeated here, so every typing board carried two of it.
    /// Dropping the duplicate let the remaining four keys spend all ten
    /// columns: 6 + 2 + 1 + 1, with nothing left over.
    static let bottomRow: [Cell?] = {
        var row: [Cell?] = Array(repeating: nil, count: columns)
        row[0] = Cell(.space, "space", colSpan: 6)
        row[6] = Cell(.delete, "⌫", colSpan: 2)
        row[8] = Cell(.cursorLeft, "Cursor left")
        row[9] = Cell(.cursorRight, "Cursor right")
        return row
    }()
}
