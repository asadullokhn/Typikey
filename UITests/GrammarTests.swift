import XCTest

// TouchChat's behavior, and the reason it feels alive: after "I am", the
// verb keys show their -ing form. The cell must not move — only its label
// changes — so this asserts both halves: the word becomes "going", and the
// key is still in the same place on the board.
final class GrammarTests: XCTestCase {
    func testVerbKeysFollowTheSentence() {
        let app = launchToKeyboard()
        guard let baseFrame = gridKey(app, "go")?.frame else {
            return XCTFail("the 'go' key is not on the home board")
        }

        // "I" then "am": "I" is a grid word, "am" is typed on the letters
        // level — the same path a user takes.
        gridKey(app, "I")?.tap()
        app.staticTexts["abc"].tap()
        app.staticTexts["a"].firstMatch.tap()
        app.staticTexts["m"].firstMatch.tap()
        app.staticTexts["Home"].tap()

        let going = app.staticTexts["going"]
        XCTAssertTrue(going.waitForExistence(timeout: 5),
                      "after 'I am' the go key should read 'going'")
        guard let relabelled = gridKey(app, "going") else {
            return XCTFail("'going' is not on the board")
        }
        XCTAssertEqual(relabelled.frame.minX, baseFrame.minX, accuracy: 2,
                       "the relabelled key moved — grid positions must never change")
        XCTAssertEqual(relabelled.frame.minY, baseFrame.minY, accuracy: 2,
                       "the relabelled key moved — grid positions must never change")
    }

    // The copula is what every AAC vendor uses to demonstrate this feature,
    // and it is the one English verb no suffix rule can ever produce. It
    // also caught two real bugs: there was no "be" key on any board, and
    // the rebuild check compared only the verb FORM — tapping "you" after
    // "I" changes the subject while leaving the form at base, so the board
    // never redrew and looked frozen.
    func testCopulaFollowsTheSubject() {
        let app = launchToKeyboard()
        guard let beFrame = gridKey(app, "be")?.frame else {
            return XCTFail("the 'be' key is not on the home board")
        }
        gridKey(app, "you")?.tap()
        XCTAssertTrue(app.staticTexts["are"].waitForExistence(timeout: 5),
                      "after 'You' the be key should read 'are'")
        XCTAssertEqual(gridKey(app, "are")?.frame.minX ?? -1, beFrame.minX, accuracy: 2,
                       "the copula key moved — grid positions must never change")
    }

    // An inverted question hands the tense to the auxiliary, so the verb
    // answers to that and not to the subject beside it. The board used to
    // agree with the subject and ignore the word in front of it, which
    // produced "can you are" and "can he goes" — wrong in every question
    // anyone would actually ask.
    func testQuestionsDoNotAgreeWithTheSubject() {
        let app = launchToKeyboard()

        gridKey(app, "can")?.tap()
        gridKey(app, "you")?.tap()
        XCTAssertTrue(app.staticTexts["be"].waitForExistence(timeout: 5),
                      "after 'Can you' the copula must read 'be' — 'can you are' is not English")
        XCTAssertFalse(app.staticTexts["are"].exists,
                       "'are' has no place after a modal")

        gridKey(app, "Clear")?.tap()
        if app.staticTexts["tap again"].waitForExistence(timeout: 2) {
            app.staticTexts["tap again"].tap()
        }

        gridKey(app, "can")?.tap()
        gridKey(app, "he")?.tap()
        XCTAssertTrue(app.staticTexts["go"].waitForExistence(timeout: 5),
                      "after 'Can he' the verb keys must read 'go' — 'can he goes' is not English")
        XCTAssertFalse(app.staticTexts["goes"].exists,
                       "third-person agreement does not survive a modal")
    }

    // Tense comes from the sentence's own time words, because the board
    // carries the design's keys and no others. "Yesterday" is an ordinary
    // word cell that also happens to place the whole sentence.
    func testATimeWordPutsTheWholeBoardInThePast() {
        let app = launchToKeyboard()
        guard let goFrame = gridKey(app, "go")?.frame else {
            return XCTFail("the 'go' key is not on the home board")
        }
        gridKey(app, "yesterday")?.tap()

        XCTAssertTrue(app.staticTexts["went"].waitForExistence(timeout: 5),
                      "'yesterday' should put the verb keys in the simple past")
        XCTAssertEqual(gridKey(app, "went")?.frame.minX ?? -1, goFrame.minX, accuracy: 2,
                       "a relabelled key must not move")

        // Past AND a subject: the copula needs both axes at once.
        gridKey(app, "you")?.tap()
        XCTAssertTrue(app.staticTexts["were"].waitForExistence(timeout: 5),
                      "past tense after 'You' should give 'were', not 'was'")
    }

    // A tense belongs to one sentence, and the context window still holds
    // the sentence before it.
    func testTenseDoesNotLeakIntoTheNextSentence() {
        let app = launchToKeyboard()
        gridKey(app, "yesterday")?.tap()
        XCTAssertTrue(app.staticTexts["went"].waitForExistence(timeout: 5), "setup: not in past tense")
        gridKey(app, ".")?.tap()
        XCTAssertTrue(app.staticTexts["go"].waitForExistence(timeout: 5),
                      "a full stop should return the board to the present")
    }

    private func launchToKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "practice field not found")
        field.tap()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
            field.tap()
        }
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 10),
                      "Typikey home board not visible — is Typikey the active keyboard?")
        return app
    }

    /// A label can appear both as a suggestion chip and as a grid key. The
    /// grid sits below the suggestion bar, so the lowest match is the key.
    private func gridKey(_ app: XCUIApplication, _ label: String) -> XCUIElement? {
        let matches = app.staticTexts.matching(NSPredicate(format: "label == %@", label))
        guard matches.count > 0 else { return nil }
        return (0..<matches.count)
            .map { matches.element(boundBy: $0) }
            .filter(\.exists)
            .max { $0.frame.minY < $1.frame.minY }
    }
}
