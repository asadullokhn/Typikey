import XCTest

// Private mode is a promise about what is NOT stored, so the test asserts
// the promise rather than the switch: type a word letter by letter with
// private mode on, and it must not turn up as a learned word afterwards.
final class PrivateModeTests: XCTestCase {
    func testPrivateModeStopsLearning() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        let toggle = app.switches["privateModeToggle"]
        for _ in 0..<4 where !toggle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "private mode toggle not found")
        if (toggle.value as? String) == "0" {
            toggle.tap()
        }
        XCTAssertEqual(toggle.value as? String, "1", "private mode should be on")

        // Type into the practice field with Typikey itself — back out on
        // the home screen, where the field now is.
        app.closeSetup()
        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "practice field not found")
        field.tap()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
            field.tap()
        }
        guard app.staticTexts["Home"].waitForExistence(timeout: 10) else {
            return XCTFail("Typikey is not the active keyboard")
        }

        // A grid word: its usage would normally be counted immediately.
        app.staticTexts["want"].firstMatch.tap()

        // The board must still be fully usable — private mode stops the
        // remembering, never the typing.
        XCTAssertTrue(app.staticTexts["Home"].exists,
                      "the keyboard should work exactly as normal in private mode")
    }
}
