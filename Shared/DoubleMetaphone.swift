import Foundation

enum DoubleMetaphone {
    struct Codes: Equatable, Sendable {
        let primary: String
        let alternate: String
    }

    static func matches(_ left: String, _ right: String) -> Bool {
        let lhs = codes(for: left)
        let rhs = codes(for: right)
        let leftCodes = Set([lhs.primary, lhs.alternate].filter { !$0.isEmpty })
        let rightCodes = Set([rhs.primary, rhs.alternate].filter { !$0.isEmpty })
        return !leftCodes.isDisjoint(with: rightCodes)
    }

    static func codes(for input: String) -> Codes {
        let folded = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let letters = Array(folded.uppercased().filter(\.isLetter))
        guard !letters.isEmpty else { return Codes(primary: "", alternate: "") }

        var index = 0
        if starts(with: ["GN", "KN", "PN", "WR", "PS"], letters: letters) {
            index = 1
        }
        var primary = ""
        var alternate = ""

        func append(_ main: String, _ other: String? = nil) {
            appendDeduplicated(main, to: &primary)
            appendDeduplicated(other ?? main, to: &alternate)
        }

        while index < letters.count, primary.count < 8 {
            let current = letters[index]
            let next = character(at: index + 1, in: letters)
            let nextTwo = slice(from: index, length: 3, in: letters)
            switch current {
            case "A", "E", "I", "O", "U", "Y":
                if index == 0 { append("A") }
            case "B": append("P")
            case "C":
                if next == "H" { append("X"); index += 1 }
                else if nextTwo == "CIA" { append("X"); index += 2 }
                else if next == "I" || next == "E" || next == "Y" { append("S") }
                else { append("K") }
            case "D":
                if next == "G", let after = character(at: index + 2, in: letters), "IEY".contains(after) {
                    append("J"); index += 2
                } else { append("T") }
            case "F": append("F")
            case "G":
                if next == "H" { index += 1 }
                else if next == "I" || next == "E" || next == "Y" { append("J", "K") }
                else { append("K") }
            case "H":
                let previous = character(at: index - 1, in: letters)
                if (index == 0 || isVowel(previous)), isVowel(next) { append("H") }
            case "J": append("J")
            case "K": append("K")
            case "L": append("L")
            case "M": append("M")
            case "N": append("N")
            case "P":
                if next == "H" { append("F"); index += 1 } else { append("P") }
            case "Q": append("K")
            case "R": append("R")
            case "S":
                if next == "H" || nextTwo == "SIO" || nextTwo == "SIA" {
                    append("X")
                    if next == "H" { index += 1 }
                } else { append("S") }
            case "T":
                if nextTwo == "TIA" || nextTwo == "TIO" { append("X"); index += 2 }
                else if next == "H" { append("0", "T"); index += 1 }
                else if nextTwo != "TCH" { append("T") }
            case "V": append("F")
            case "W": if isVowel(next) { append("W") }
            case "X": append("KS")
            case "Z": append("S")
            default: break
            }
            index += 1
        }
        return Codes(primary: primary, alternate: alternate)
    }

    private static func starts(with prefixes: [String], letters: [Character]) -> Bool {
        let start = String(letters.prefix(2))
        return prefixes.contains(start)
    }

    private static func character(at index: Int, in letters: [Character]) -> Character? {
        guard letters.indices.contains(index) else { return nil }
        return letters[index]
    }

    private static func slice(from index: Int, length: Int, in letters: [Character]) -> String {
        guard index < letters.count else { return "" }
        return String(letters[index..<min(index + length, letters.count)])
    }

    private static func isVowel(_ character: Character?) -> Bool {
        guard let character else { return false }
        return "AEIOUY".contains(character)
    }

    private static func appendDeduplicated(_ value: String, to output: inout String) {
        for character in value where output.last != character {
            output.append(character)
        }
    }
}
