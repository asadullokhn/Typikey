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

    // Tense is the user's choice because nothing in the text can supply it:
    // "you" says who, never when. One key cycles now / past / future and
    // every verb key follows it, in place.
    func testTenseKeyPutsTheWholeBoardInThePast() {
        let app = launchToKeyboard()
        guard let goFrame = gridKey(app, "go")?.frame else {
            return XCTFail("the 'go' key is not on the home board")
        }
        tenseKey(in: app).tap()

        XCTAssertTrue(app.staticTexts["went"].waitForExistence(timeout: 5),
                      "the tense key should put the verb keys in the simple past")
        XCTAssertEqual(gridKey(app, "went")?.frame.minX ?? -1, goFrame.minX, accuracy: 2,
                       "a relabelled key must not move")

        // Past AND a subject: the copula needs both axes at once.
        gridKey(app, "you")?.tap()
        XCTAssertTrue(app.staticTexts["were"].waitForExistence(timeout: 5),
                      "past tense after 'You' should give 'were', not 'was'")
    }

    // A tense belongs to one sentence. Left set, it silently corrupts the
    // next one.
    func testTenseResetsAtTheEndOfASentence() {
        let app = launchToKeyboard()
        tenseKey(in: app).tap()
        XCTAssertTrue(app.staticTexts["went"].waitForExistence(timeout: 5), "setup: not in past tense")
        gridKey(app, ".")?.tap()
        XCTAssertTrue(app.staticTexts["go"].waitForExistence(timeout: 5),
                      "a full stop should return the board to the present")
    }

    /// The tense key reads "Tense" over whichever tense it is set to, so it
    /// is matched on the stable half of its label.
    private func tenseKey(in app: XCUIApplication) -> XCUIElement {
        let key = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Tense")).firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5), "the tense key is not on the board")
        return key
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
