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
}
