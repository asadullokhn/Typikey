import XCTest
@testable import Typikey

final class CompletionSanitizerTests: XCTestCase {
    func testUsesFirstUsableCandidateAndReturnsAtMostFiveWords() {
        let words = CompletionSanitizer.words(from: [
            "   ",
            "go to the park with Mum tomorrow",
            "ignored candidate",
        ])

        XCTAssertEqual(words, ["go", "to", "the", "park", "with"])
    }

    func testRemovesTrailingPunctuationAndBareSymbols() {
        let words = CompletionSanitizer.words(from: ["please help! ▸ -"])

        XCTAssertEqual(words, ["please", "help"])
    }

    func testEmptyCandidatesReturnNil() {
        XCTAssertNil(CompletionSanitizer.words(from: ["  ", "…"]))
    }
}
