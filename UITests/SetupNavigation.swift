import XCTest

/// Everything that is not the board lives behind `Setup` now.
///
/// The app's home screen is the board (Keiko's design): page controls,
/// practice field, keyboard. My Words, screen learning, the settings and
/// the diagnostics moved into a sheet behind the fourth button. Tests that
/// assert on one of those cards go through the same door a person does,
/// which is also what keeps them honest about where the thing actually is.
extension XCUIApplication {
    func openSetup(file: StaticString = #filePath, line: UInt = #line) {
        let pageMenu = buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Name of Page'")).firstMatch
        XCTAssertTrue(pageMenu.waitForExistence(timeout: 10),
                      "Page menu not found on the home screen", file: file, line: line)
        pageMenu.tap()
        let setup = buttons["Setup"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5),
                      "Setup action not found in the page menu", file: file, line: line)
        setup.tap()
    }

    func closeSetup(file: StaticString = #filePath, line: UInt = #line) {
        let done = buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "Setup sheet has no Done button", file: file, line: line)
        done.tap()
    }

    /// The one route to the real keyboard extension.
    ///
    /// The home board is a working demo that never raises a keyboard, so a
    /// test that needs the extension goes where a person goes: Setup, then
    /// the practice conversation, whose reply box is a real text field.
    @discardableResult
    func focusRealKeyboard(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        openSetup(file: file, line: line)
        let practice = staticTexts["Practice conversation"].firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 10),
                      "Practice conversation not found in Setup", file: file, line: line)
        practice.tap()

        let field = textViews["demoReplyField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "practice reply field not found", file: file, line: line)
        field.tap()
        if buttons["Continue"].waitForExistence(timeout: 3) {
            buttons["Continue"].tap()
            field.tap()
        }
        // Which keyboard is active is simulator state, not repo state, and a
        // freshly booted device comes up on the system one. Cycle the globe
        // until our board appears rather than failing on someone's setup.
        for _ in 0..<6 {
            if staticTexts["Home"].waitForExistence(timeout: 2) { break }
            let globe = buttons["Next keyboard"].exists
                ? buttons["Next keyboard"]
                : buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] 'keyboard'")).firstMatch
            guard globe.exists else { break }
            globe.tap()
        }
        XCTAssertTrue(staticTexts["Home"].exists,
                      "Typikey never became the active keyboard — is it added in Settings?",
                      file: file, line: line)
        return field
    }
}
