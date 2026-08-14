import Foundation

struct PrefixTrie: Sendable {
    private struct Word: Sendable {
        let text: String
        let normalized: String
        let frequency: Int
    }

    private struct Node: Sendable {
        var children: [Character: Int] = [:]
        var bestWordIndexes: [Int] = []
    }

    private static let storedCompletionsPerNode = 16
    private let words: [Word]
    private var nodes: [Node]

    init(words input: [(text: String, frequency: Int)]) {
        var unique: [String: (text: String, frequency: Int, order: Int)] = [:]
        for (order, entry) in input.enumerated() {
            let normalized = Self.normalize(entry.text)
            guard !normalized.isEmpty else { continue }
            if let existing = unique[normalized], existing.frequency >= entry.frequency { continue }
            unique[normalized] = (entry.text, max(0, entry.frequency), order)
        }

        words = unique
            .map { Word(text: $0.value.text, normalized: $0.key, frequency: $0.value.frequency) }
            .sorted {
                if $0.frequency != $1.frequency { return $0.frequency > $1.frequency }
                return $0.normalized < $1.normalized
            }

        nodes = [Node()]
        for index in words.indices {
            add(index, to: 0)
            var nodeIndex = 0
            for character in words[index].normalized {
                if let child = nodes[nodeIndex].children[character] {
                    nodeIndex = child
                } else {
                    let child = nodes.count
                    nodes.append(Node())
                    nodes[nodeIndex].children[character] = child
                    nodeIndex = child
                }
                add(index, to: nodeIndex)
            }
        }
    }

    func completions(for prefix: String, limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        var nodeIndex = 0
        for character in Self.normalize(prefix) {
            guard let child = nodes[nodeIndex].children[character] else { return [] }
            nodeIndex = child
        }
        return nodes[nodeIndex].bestWordIndexes.prefix(limit).map { words[$0].text }
    }

    private mutating func add(_ wordIndex: Int, to nodeIndex: Int) {
        guard nodes[nodeIndex].bestWordIndexes.count < Self.storedCompletionsPerNode else { return }
        nodes[nodeIndex].bestWordIndexes.append(wordIndex)
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }
}
