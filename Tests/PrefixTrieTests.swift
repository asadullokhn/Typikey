import XCTest
@testable import Typikey

final class PrefixTrieTests: XCTestCase {
    func testEmptyPrefixReturnsHighestFrequencyOpeners() {
        let trie = PrefixTrie(words: [
            ("hello", 3),
            ("I", 10),
            ("please", 7),
        ])

        XCTAssertEqual(trie.completions(for: "", limit: 2), ["I", "please"])
    }

    func testLookupIsCaseInsensitiveAndPreservesStoredCasing() {
        let trie = PrefixTrie(words: [("Home", 4), ("home", 2), ("homework", 3)])

        XCTAssertEqual(trie.completions(for: "HO", limit: 3), ["Home", "homework"])
    }

    func testApostropheIsPartOfPrefix() {
        let trie = PrefixTrie(words: [("don't", 5), ("done", 4)])

        XCTAssertEqual(trie.completions(for: "don'", limit: 3), ["don't"])
    }

    func testNonPositiveLimitReturnsNothing() {
        let trie = PrefixTrie(words: [("hello", 1)])

        XCTAssertEqual(trie.completions(for: "h", limit: 0), [])
    }

    func testLookupMeetsImmediatePredictionBudget() {
        let words = (0..<1_000).map { ("word\($0)", 1_000 - $0) }
        let trie = PrefixTrie(words: words)
        let clock = ContinuousClock()
        var durations: [Duration] = []

        for index in 0..<1_000 {
            let start = clock.now
            _ = trie.completions(for: "word\(index % 10)", limit: 3)
            durations.append(start.duration(to: clock.now))
        }

        let p95 = durations.sorted()[949]
        XCTAssertLessThan(p95, .milliseconds(10))
    }
}
