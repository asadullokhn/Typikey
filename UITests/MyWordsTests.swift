import XCTest

// The container app's own sandbox is deterministic on the simulator (unlike
// the keyboard extension's app-group access, which is gated on Full Access
// — see the design doc's Testing section). This test stays entirely on the
// app side: navigate to My Words, type a word using Typikey itself (the
// only keyboard enabled on the test simulator, so plain typeText() can't
// be used — it has no hardware-keyboard fallback), and assert it lands in
// the list.
final class MyWordsTests: XCTestCase {
    func testManualAddShowsInList() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        let link = app.staticTexts["My Words & Phrases"]
        if link.waitForExistence(timeout: 5) {
            link.tap()
        } else {
            app.buttons["My Words & Phrases"].tap()
        }

        // The add field sits below the candidate sections, and a List only
        // renders what is on screen — on a phone it starts out of view.
        let field = app.textFields["myWordsField"]
        for _ in 0..<4 where !field.exists {
            app.swipeUp()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()

        // Typikey may open on Home (grid) or already on letters, depending
        // on the last-used level restored for this field signature.
        if app.staticTexts["ABC"].waitForExistence(timeout: 3) {
            app.staticTexts["ABC"].tap()
        }

        for letter in ["q", "u", "a", "n", "d", "o"] {
            let key = app.staticTexts[letter].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), "letter key '\(letter)' not found on Typikey")
            key.tap()
        }

        app.buttons["myWordsAdd"].tap()
        XCTAssertTrue(app.staticTexts["quando"].waitForExistence(timeout: 5),
                      "manually added word should appear in My Words")
    }
}
