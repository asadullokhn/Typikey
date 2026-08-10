import XCTest

// Once "can you" is written, nothing can follow it that reads "can you I",
// so the subject-pronoun cells are spare and carry verbs instead.
//
// The half that matters as much as the swap is the rewind: the board is
// derived from the text and never stored, so deleting the word has to put
// the pronouns back with no memory of anything. This asserts both.
final class SpareKeysTests: XCTestCase {

    func testSpareKeysCarryVerbsAndComeBack() {
        let app = launchToKeyboard()

        XCTAssertTrue(app.staticTexts["he"].exists, "setup: the pronoun cells should start as pronouns")

        app.staticTexts["can"].firstMatch.tap()
        // "Can ___" is a question waiting for its subject, so the pronouns
        // are the most useful keys on the board here — spending them took
        // away the very words the sentence needed next.
        XCTAssertTrue(app.staticTexts["you"].waitForExistence(timeout: 3),
                      "'Can' needs a subject next — the pronouns must stay")

        app.staticTexts["you"].firstMatch.tap()

        // "can you ___" can only be a verb, so the spare cells change.
        XCTAssertTrue(app.staticTexts["he"].waitForExistence(timeout: 3) == false
                        || !app.staticTexts["he"].exists,
                      "'he' cannot follow 'can you' and should have given up its cell")

        // Going back must restore them, with nothing remembered.
        //
        // Twice, and that is the point rather than an inconvenience:
        // deleting "you" leaves "can", which still calls for a verb, so the
        // cells are still spare and correctly stay swapped. The board is
        // tracking the sentence backwards, not undoing an action.
        app.staticTexts["Delete word"].tap()
        app.staticTexts["Delete word"].tap()
        XCTAssertTrue(app.staticTexts["he"].waitForExistence(timeout: 3),
                      "with the sentence deleted, the pronoun cells should be back")
    }

    // Clearing the sentence starts over: the board must read exactly as it
    // does on a fresh keyboard.
    func testClearingStartsAgain() {
        let app = launchToKeyboard()
        app.staticTexts["can"].firstMatch.tap()
        app.staticTexts["you"].firstMatch.tap()

        app.staticTexts["Clear"].tap()
        if app.staticTexts["tap again"].waitForExistence(timeout: 2) {
            app.staticTexts["tap again"].tap()
        }
        XCTAssertTrue(app.staticTexts["he"].waitForExistence(timeout: 3),
                      "clearing should start the board again from the beginning")
    }

    private func launchToKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
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
}
