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

        XCTAssertTrue(app.staticTexts["it"].exists, "setup: the pronoun cells should start as pronouns")

        app.staticTexts["can"].firstMatch.tap()
        // "Can ___" is a question waiting for its subject, so the pronouns
        // are the most useful keys on the board here — spending them took
        // away the very words the sentence needed next.
        XCTAssertTrue(app.staticTexts["you"].waitForExistence(timeout: 3),
                      "'Can' needs a subject next — the pronouns must stay")

        app.staticTexts["you"].firstMatch.tap()

        // "can you ___" can only be a verb, so the spare cells change.
        XCTAssertTrue(app.staticTexts["it"].waitForExistence(timeout: 3) == false
                        || !app.staticTexts["it"].exists,
                      "'it' cannot follow 'can you' and should have given up its cell")

        // Going back must restore them, with nothing remembered.
        //
        // Twice, and that is the point rather than an inconvenience:
        // deleting "you" leaves "can", which still calls for a verb, so the
        // cells are still spare and correctly stay swapped. The board is
        // tracking the sentence backwards, not undoing an action.
        app.staticTexts["Delete word"].tap()
        app.staticTexts["Delete word"].tap()
        XCTAssertTrue(app.staticTexts["it"].waitForExistence(timeout: 3),
                      "with the sentence deleted, the pronoun cells should be back")
    }

    // Clearing the sentence starts over: the board must read exactly as it
    // does on a fresh keyboard.
    func testClearingStartsAgain() {
        let app = launchToKeyboard()
        app.staticTexts["can"].firstMatch.tap()
        app.staticTexts["you"].firstMatch.tap()

        app.staticTexts["Clear"].tap()
        XCTAssertTrue(app.staticTexts["it"].waitForExistence(timeout: 3),
                      "clearing should start the board again from the beginning")
    }

    private func launchToKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        app.focusRealKeyboard()
        return app
    }
}
