import XCTest

/// Editing a board, through the door a person uses.
///
/// "Edit Page" once did two things: it opened the page-name field, and it
/// turned every key into a target that opened the button editor. Moving the
/// app onto the keyboard's own board kept the first and silently dropped the
/// second — the editor was still in the binary, with nothing left that could
/// present it. Renaming still worked, which is what made it look fine.
final class PageEditingTests: XCTestCase {

    func testEditingAKeyOpensTheEditorAndKeepsTheChange() {
        let app = launch()
        app.buttons["Edit Page"].tap()

        let key = app.staticTexts["want"].firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5), "the 'want' key is not on the home board")
        key.tap()

        XCTAssertTrue(app.staticTexts["Button Label"].waitForExistence(timeout: 5),
                      "tapping a key while editing must open the button editor")

        let label = app.textFields["buttonLabelField"]
        XCTAssertTrue(label.waitForExistence(timeout: 5), "the editor has no label field")
        label.tap()
        let existing = (label.value as? String) ?? ""
        label.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        label.typeText("Zoq")
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Zoq"].firstMatch.waitForExistence(timeout: 5),
                      "the edited label should be on the board")
    }

    /// A blank cell is where a new key goes, so it has to be reachable. The
    /// board draws only the cells that carry a word, which is right when
    /// somebody is talking and wrong when they are building — and a new page
    /// is nothing but blank cells.
    func testAnEmptyCellIsReachableWhileEditing() {
        let app = launch()
        app.buttons["Add New Page"].tap()   // lands on an empty page, editing

        let empty = app.staticTexts["Empty cell"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5),
                      "a new page's cells must be targets, or nothing can be put on it")
        empty.tap()
        XCTAssertTrue(app.staticTexts["Button Label"].waitForExistence(timeout: 5),
                      "tapping a blank cell must open the button editor")
    }

    /// Nothing is a target when nobody is editing — a blank cell is a gap in
    /// the board, and hitting it must not open anything.
    func testEmptyCellsAreNotTargetsWhenNotEditing() {
        let app = launch()
        app.buttons["Add New Page"].tap()
        app.buttons["Edit Page"].tap()      // leave editing

        XCTAssertFalse(app.staticTexts["Empty cell"].exists,
                       "blank cells belong to the editor, not to talking")
    }

    /// Typing is what the board does when nobody is editing it, and turning
    /// editing off has to give that back.
    func testLeavingEditingTypesAgain() {
        let app = launch()
        app.buttons["Edit Page"].tap()
        app.buttons["Edit Page"].tap()

        app.staticTexts["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["want"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tap a key from the keyboard."].exists,
                       "a tapped word should replace the placeholder")
    }

    /// Editing changes what every key on the board does, so being in it has
    /// to be answerable at a glance. The colour says so; this says so to
    /// anyone not reading the colour.
    func testEditModeAnnouncesItself() {
        let app = launch()
        let edit = app.buttons["Edit Page"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertFalse(edit.isSelected, "not editing yet")

        edit.tap()
        XCTAssertTrue(edit.isSelected, "edit mode must be announced, not only coloured")

        edit.tap()
        XCTAssertFalse(edit.isSelected, "leaving edit mode must clear it")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-uiTestPages", "none"]
        app.launch()
        return app
    }
}
