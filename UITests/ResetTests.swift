import XCTest

/// Reset is the one thing in Setup that cannot be taken back, so the test
/// asserts the effect rather than the message. A reset that reports success
/// and leaves the old board in place is the worst possible outcome: the
/// person who ran it now believes the device is clean.
final class ResetTests: XCTestCase {
    func testResetRestoresTheShippedBoard() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-skipOnboarding", "-uiTestPages",
            #"[{"id":"home","name":"Zoq Board","cells":[{"id":"a","label":"Zoq","arranged":true}],"arranged":true}]"#,
        ]
        app.launch()

        let name = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Zoq Board'")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "setup: the stored board should be in use")

        app.openSetup()
        let reset = app.buttons["resetEverything"]
        for _ in 0..<10 where !reset.exists {
            app.swipeUp()
        }
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "no reset button in Setup")
        reset.tap()

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5),
                      "reset must ask before it wipes anything")
        app.alerts.buttons["Reset"].tap()
        XCTAssertTrue(app.staticTexts["resetConfirmation"].waitForExistence(timeout: 5))

        app.closeSetup()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Keyboard Home Pg 1'"))
                .firstMatch.waitForExistence(timeout: 10),
            "the shipped board should be back straight away, not after a relaunch")
        XCTAssertTrue(app.staticTexts["I"].firstMatch.exists, "the shipped words should be back")
        XCTAssertFalse(app.staticTexts["Zoq"].exists, "the arranged board should be gone")
    }

    func testCancellingChangesNothing() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-uiTestPages", "none"]
        app.launch()
        app.openSetup()

        let reset = app.buttons["resetEverything"]
        for _ in 0..<10 where !reset.exists {
            app.swipeUp()
        }
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        app.alerts.buttons["Cancel"].tap()

        XCTAssertFalse(app.staticTexts["resetConfirmation"].exists,
                       "cancelling must not report a reset that never happened")
    }
}
