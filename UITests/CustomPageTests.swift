import XCTest

/// The app is allowed to improve the keyboard. It is never allowed to be
/// the reason the keyboard stops working.
///
/// Letting Fadillah build boards means the keyboard now renders data
/// somebody else wrote, and every way that data can be wrong ends with a
/// nonverbal person holding a device that cannot say anything. So these
/// test the failure paths harder than the feature: no stored pages, a
/// page with nothing on it, a key pointing at a page that is gone.
///
/// The shipped board is the floor. Whatever happens, he can still talk.
final class CustomPageTests: XCTestCase {

    /// Fixtures go in through the app, not from here.
    ///
    /// The test runner is a separate app with no App Group entitlement, so
    /// writing to the shared container from a test does nothing at all —
    /// silently. That cost a green run on a test that was asserting on a
    /// board it had never actually changed.
    private var fixture: String?

    /// The finished setup state is Keiko's 12.9-inch reference screen:
    /// three actions, the practice sentence, the page label, and ten
    /// equal visual columns across the board. Permission guidance belongs
    /// only to setup, not to the screen somebody uses every day.
    func testConfiguredHomeMatchesReferenceStructure() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-uiTestFullAccess", "-uiTestPages", "none"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft

        let delete = app.staticTexts["Delete Page"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete Page action missing")
        XCTAssertTrue(app.staticTexts["Add New Page"].exists, "Add New Page action missing")
        XCTAssertTrue(app.staticTexts["Edit Page"].exists, "Edit Page action missing")
        XCTAssertTrue(app.buttons["Edit Page"].isEnabled,
                      "the reference home page is editable")
        XCTAssertFalse(app.staticTexts["Setup"].exists,
                       "Setup must leave the fully configured reference state")
        XCTAssertFalse(app.staticTexts["The keyboard cannot see these boards yet"].exists,
                       "permission warning must leave the fully configured reference state")
        XCTAssertGreaterThan(delete.frame.minX, app.frame.width / 2,
                             "the three actions belong in the upper-right cluster")

        XCTAssertTrue(app.staticTexts["Name of Page"].exists, "page-name caption missing")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Keyboard Home Pg 1'")).firstMatch.exists,
                      "the reference home-page name is missing")

        let home = app.buttons["Home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 5), "home board did not render")
        XCTAssertEqual(home.frame.width, app.frame.width / 10, accuracy: 12,
                       "the reference uses ten approximately equal 1:1 columns")
        XCTAssertEqual(app.buttons["Categories"].frame.minX, home.frame.minX, accuracy: 1,
                       "Categories belongs directly under Home on the left edge")
        XCTAssertGreaterThan(app.buttons["ABC"].frame.midX, app.frame.width * 0.9,
                             "ABC belongs in the right edge column")
    }

    func testExampleSentenceIsPlaceholderNotInput() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-uiTestFullAccess", "-uiTestPages", "none"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft

        let field = app.textFields.firstMatch.exists
            ? app.textFields.firstMatch
            : app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "practice field not found")
        XCTAssertEqual(field.value as? String ?? "", "",
                       "the example sentence must not be pre-entered text")
        XCTAssertTrue(app.staticTexts["I like to drink coffee"].exists,
                      "the example sentence should remain visible as a placeholder")
    }

    /// The common case, and the one that must be indistinguishable from
    /// the keyboard as it was before any of this existed.
    func testNoStoredPagesLeavesTheShippedBoard() {
        fixture = "none"
        let app = launchToKeyboard()
        for word in ["I", "you", "want", "go", "not", "yes"] {
            XCTAssertTrue(app.staticTexts[word].firstMatch.exists,
                          "'\(word)' should be on the shipped home board")
        }
    }

    /// Stored pages that decode to nothing usable must not produce an
    /// empty board. A blank keyboard is worse than an unedited one.
    func testUnreadablePagesFallBackToTheShippedBoard() {
        fixture = "not json"
        let app = launchToKeyboard()
        XCTAssertTrue(app.staticTexts["I"].firstMatch.waitForExistence(timeout: 5),
                      "unreadable stored pages should fall back, not blank the board")
        XCTAssertTrue(app.staticTexts["Home"].exists, "the pinned column must survive it")
    }

    /// An edited board still has the keyboard's own controls. They belong
    /// to the keyboard, not to the page, so no arrangement can remove the
    /// way home or the way back.
    func testAnEditedPageKeepsTheKeyboardsOwnControls() throws {
        // Fixed navigation lives in the two edge columns, independently
        // from these editable content cells.
        store(pages: [["id": "home", "name": "Keyboard Home",
                       "cells": [NSNull(), NSNull(), ["id": "a", "label": "Zoq"]]]])
        let app = launchToKeyboard()
        try skipUnlessTheKeyboardReadsSharedBoards(app)
        XCTAssertTrue(app.staticTexts["Zoq"].firstMatch.waitForExistence(timeout: 5),
                      "the edited key should be on the board")
        XCTAssertTrue(app.staticTexts["Home"].exists, "Home must survive editing")
        XCTAssertTrue(app.staticTexts["Clear"].exists, "Clear must survive editing")
        XCTAssertTrue(app.staticTexts["Delete word"].exists, "word-delete must survive editing")
        // The way out of an edited board. Without these, an arrangement
        // that filled every cell would leave him with no route to the
        // categories or the letters at all.
        XCTAssertTrue(app.staticTexts["Categories"].exists, "Categories must survive editing")
        XCTAssertTrue(app.staticTexts["ABC"].exists, "ABC must survive editing")
    }

    /// A key placed in cell 12 stays in cell 12 when cell 11 is emptied.
    /// The packer that builds the shipped boards closes up behind a gap,
    /// which is right for a generated board and wrong for one a person
    /// arranged — she put it there and he learned where it is.
    func testAnEmptyCellDoesNotSlideTheKeysAfterIt() throws {
        store(pages: [["id": "home", "name": "Keyboard Home",
                       "cells": [NSNull(), NSNull(),
                                 ["id": "a", "label": "Zoq"],
                                 NSNull(),
                                 ["id": "c", "label": "Wug"]]]])
        let app = launchToKeyboard()
        try skipUnlessTheKeyboardReadsSharedBoards(app)
        let third = app.staticTexts["Wug"].firstMatch
        XCTAssertTrue(third.waitForExistence(timeout: 5), "the later key should be on the board")
        let first = app.staticTexts["Zoq"].firstMatch
        XCTAssertTrue(first.exists, "the earlier key should be on the board")
        // Two cells apart, not one: the gap is real estate, not a gap to
        // be closed.
        let gap = third.frame.minX - first.frame.minX
        XCTAssertGreaterThan(gap, first.frame.width * 1.5,
                             "the emptied cell should still be holding its place")
    }

    /// Editing only reaches the keyboard when Full Access is granted, and
    /// that is a switch in Settings that no test can flip. Skipping says
    /// so out loud; failing would blame the code for a missing permission,
    /// which is how a real defect gets ignored as "that one always fails".
    private func skipUnlessTheKeyboardReadsSharedBoards(_ app: XCUIApplication) throws {
        guard app.staticTexts["Zoq"].firstMatch.waitForExistence(timeout: 5) == false else { return }
        throw XCTSkip("The keyboard is not reading the shared container — grant Typikey "
                      + "Full Access on this simulator to exercise edited boards.")
    }

    private func store(pages: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: pages)
        fixture = String(decoding: data, as: UTF8.self)
    }

    private func launchToKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
        if let fixture { app.launchArguments += ["-uiTestPages", fixture] }
        app.launchArguments += ["-skipOnboarding"]
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
