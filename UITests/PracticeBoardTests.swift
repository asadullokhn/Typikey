import XCTest

/// The home board is a working keyboard, not a picture of one: every key
/// does its job, and none of them raises the system keyboard over the board
/// they are demonstrating.
final class PracticeBoardTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-uiTestFullAccess", "-uiTestPages", "none"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Home"].firstMatch.waitForExistence(timeout: 10),
                      "board did not render")
        return app
    }

    /// `.accessibilityElement()` on a stack yields an "other" element, not a
    /// static text, so match on identifier across any type.
    private func line(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)
            .matching(identifier: "practiceLine").firstMatch.label
    }

    func testWordKeysTypeIntoThePracticeLine() {
        let app = launch()
        app.buttons["I"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertEqual(line(app), "I want ", "word keys should compose a sentence")
        XCTAssertEqual(app.keyboards.count, 0,
                       "the system keyboard must never open over the board")
    }

    func testDeleteWordAndClearBothWork() {
        let app = launch()
        app.buttons["I"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        app.buttons["Delete word"].firstMatch.tap()
        XCTAssertEqual(line(app), "I ", "Delete word removes the last word only")

        app.buttons["Clear"].firstMatch.tap()
        XCTAssertEqual(line(app), "", "Clear erases on one tap")
    }

    func testABCOpensTheLetterBoardAndTypes() {
        let app = launch()
        app.buttons["ABC"].firstMatch.tap()

        let q = app.buttons["q"].firstMatch
        XCTAssertTrue(q.waitForExistence(timeout: 5), "ABC should open the letter board")
        q.tap()
        app.buttons["u"].firstMatch.tap()
        XCTAssertEqual(line(app), "qu", "letter keys type single characters")

        // The right edge offers 123 once you are already on abc.
        XCTAssertTrue(app.buttons["123"].firstMatch.exists,
                      "the right edge should offer 123 from the letter board")
        app.buttons["123"].firstMatch.tap()
        XCTAssertTrue(app.buttons["1"].firstMatch.waitForExistence(timeout: 5),
                      "123 should open the number board")
        XCTAssertEqual(app.keyboards.count, 0,
                       "the system keyboard must never open over the board")
    }

    func testCategoriesOpensTheBoardListAndNavigates() {
        let app = launch()
        app.buttons["Categories"].firstMatch.tap()

        let core = app.buttons["Core"].firstMatch
        XCTAssertTrue(core.waitForExistence(timeout: 5),
                      "Categories should list the boards, not jump past them")
        XCTAssertTrue(app.buttons["Food"].firstMatch.exists,
                      "every category should be listed")
        core.tap()

        XCTAssertTrue(app.buttons["Home"].firstMatch.waitForExistence(timeout: 5),
                      "tapping a category should open it")
        XCTAssertFalse(app.buttons["Food"].firstMatch.exists,
                       "the category list should be replaced by the board")
    }

    func testHomeReturnsFromTheLetterBoard() {
        let app = launch()
        app.buttons["ABC"].firstMatch.tap()
        XCTAssertTrue(app.buttons["q"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Home"].firstMatch.tap()
        XCTAssertTrue(app.buttons["want"].firstMatch.waitForExistence(timeout: 5),
                      "Home should come back to the word board")
    }
}
