import XCTest
@testable import Typikey

final class WordJoinTests: XCTestCase {

    /// The whole point: three keys, one address, no spaces.
    func testAddressComesOutAsOneToken() {
        var composer = PracticeComposer()
        composer.insertWord("www.")
        composer.insertWord("google")
        composer.insertWord(".com")
        XCTAssertEqual(composer.text, "www.google.com ")
    }

    func testOrdinaryWordsAreStillSpaced() {
        var composer = PracticeComposer()
        composer.insertWord("I")
        composer.insertWord("want")
        XCTAssertEqual(composer.text, "I want ")
    }

    /// A full stop ends a sentence; it must not glue the next word on.
    func testSentencePunctuationDoesNotJoin() {
        var composer = PracticeComposer()
        composer.insertWord("go")
        composer.insertWord(".")
        composer.insertWord("now")
        XCTAssertEqual(composer.text, "go. now ")
    }

    func testJoinerClassification() {
        XCTAssertTrue(WordJoin.trails("www."))
        XCTAssertTrue(WordJoin.leads(".com"))
        XCTAssertFalse(WordJoin.trails("."), "a bare stop is punctuation, not an address")
        XCTAssertFalse(WordJoin.leads("."))
        XCTAssertFalse(WordJoin.trails("hello"))
        XCTAssertTrue(WordJoin.continues("www."))
        XCTAssertFalse(WordJoin.continues("Hello. "), "a finished sentence leaves a space")
    }
}
