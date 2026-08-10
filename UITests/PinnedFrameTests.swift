import XCTest

// Invariant 9, in the form the team's design left it: ONE pinned column,
// on the left, occupying identical frames on every level. Enter, ⌄ and →
// moved into the content grid, so they are no longer part of this promise
// — what is asserted about them instead is that they exist on the word
// boards, which is `testGridControlsPresentOnWordBoards`.
// Keys are plain UILabels, so they surface as staticTexts.
// PRECONDITION (same as KeyboardHeightTests): Typikey enabled on the
// simulator and Connect Hardware Keyboard OFF.
final class PinnedFrameTests: XCTestCase {

    // The fourth pinned slot is deliberately absent from this list. It
    // held EN/MS until Malay came out of the MVP and now holds Hide
    // keyboard — except that it holds the system globe (a real UIButton,
    // not a staticText) whenever iOS asks for a keyboard switcher, which
    // is every configuration with a second keyboard installed, i.e. every
    // real device and this simulator. Asserting on it would be asserting
    // on which keyboards happen to be installed.
    private let pinnedLabels = ["Home", "Clear", "Delete word"]

    func testPinnedKeysIdenticalAcrossLevels() {
        let app = launchToTypikey()

        let baseline = frames(of: pinnedLabels, in: app)
        for (label, frame) in baseline {
            XCTAssertFalse(frame.isEmpty, "\(label) missing on home level")
            XCTAssertLessThan(frame.midX, app.frame.width / 2,
                              "\(label) belongs to the LEFT pinned column")
        }

        app.staticTexts["Categories"].tap()
        assertFrames(baseline, in: app, level: "categories")

        app.staticTexts["Core"].tap()
        assertFrames(baseline, in: app, level: "words")

        app.staticTexts["Home"].tap()
        app.staticTexts["abc"].tap()
        assertFrames(baseline, in: app, level: "letters")

        app.staticTexts["123"].tap()
        assertFrames(baseline, in: app, level: "numbers")
    }

    // Enter and cursor-right live inside the grid, placed before any word
    // is packed, so this also proves the packer never lets a word overwrite
    // one of them.
    //
    // Hide keyboard is in whichever place the globe left free: the pinned
    // column normally, the grid when iOS took the pinned slot for its
    // switcher. Either satisfies this — what matters is that there is
    // exactly one way to put the keyboard away, on every board.
    func testGridControlsPresentOnWordBoards() {
        let app = launchToTypikey()
        for level in ["home", "categories"] {
            XCTAssertTrue(app.staticTexts["Hide keyboard"].exists
                            || app.staticTexts["Hide\nkeyboard"].exists,
                          "hide-keyboard missing on \(level)")
            XCTAssertTrue(app.staticTexts["Cursor right"].exists, "cursor-right missing on \(level)")
            XCTAssertTrue(app.staticTexts["return"].exists || app.staticTexts["Done"].exists
                            || app.staticTexts["Go"].exists || app.staticTexts["Send"].exists
                            || app.staticTexts["Search"].exists,
                          "Enter missing on \(level)")
            if level == "home" { app.staticTexts["Categories"].tap() }
        }
    }

    // Character-level repair belongs to the levels where characters are
    // typed: the word boards have no ⌫ or ←, the letters level has both.
    func testCharacterToolsLiveOnTheTypingLevels() {
        let app = launchToTypikey()
        XCTAssertFalse(app.staticTexts["Cursor left"].exists, "no cursor-left on a word board")
        app.staticTexts["abc"].tap()
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 3), "letters level did not open")
        XCTAssertTrue(app.staticTexts["⌫"].exists, "single-character delete missing on letters")
        XCTAssertTrue(app.staticTexts["Cursor left"].exists, "cursor-left missing on letters")
    }

    func testHomeWordTapInsertsWord() {
        let app = launchToTypikey()
        app.staticTexts["want"].tap()
        let field = practiceField(in: app)
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.contains("Want"),
                      "tapping the 'want' cell should insert 'Want ' (sentence-start capitalization), got: \(value)")
    }

    func testClearAllRequiresArmingTap() {
        let app = launchToTypikey()
        app.staticTexts["want"].tap()
        var value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("Want"), "setup: word not inserted")

        app.staticTexts["Clear"].tap()
        value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("Want"), "first tap must only arm, not clear")
        XCTAssertTrue(app.staticTexts["tap again"].waitForExistence(timeout: 2),
                      "armed clear-all should relabel to 'tap again'")

        app.staticTexts["tap again"].tap()
        value = practiceField(in: app).value as? String ?? ""
        XCTAssertFalse(value.contains("Want"), "second tap should clear the text")
    }

    func testManualLevelSurvivesReshow() {
        let app = launchToTypikey()
        app.staticTexts["abc"].tap()
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 3), "letters level did not open")
        (app.staticTexts["Hide keyboard"].exists
            ? app.staticTexts["Hide keyboard"] : app.staticTexts["Hide\nkeyboard"]).tap()
        practiceField(in: app).tap() // same field, same signature
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 5),
                      "manual level was reset on re-show — intent mapping must not refire for an unchanged field signature")
    }

    // On the simulator FoundationModels generation always fails, so this
    // asserts the degrade contract: the bar and typing behave exactly as
    // before the completion feature existed.
    func testDegradedCompletionKeepsBarWorking() {
        let app = launchToTypikey()
        // Subject then verb, in that order. This used to tap "want" and
        // then "I", which stopped working the day the board started
        // following the sentence: nothing in English reads "want I", so
        // the `I` cell is deliberately spent after a transitive verb and
        // carries a noun instead. The test was asserting that typing
        // survives a degraded completion engine and happened to pick a
        // word pair the board now refuses to offer.
        //
        // .firstMatch: once this pair has run before, the learned-bigram
        // suggestion bar (existing feature, unrelated to completion) also
        // offers "want" after "I", so the plain label is ambiguous. Both
        // the grid cell and the suggestion button route through the same
        // insertWord(_:), so either match proves the same thing.
        app.staticTexts["I"].firstMatch.tap()
        app.staticTexts["want"].firstMatch.tap()
        let value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("I") && value.lowercased().contains("want"),
                      "typing must work while the completion engine is degraded, got: \(value)")
        XCTAssertTrue(app.staticTexts["Home"].exists, "keyboard frame must be intact")
    }

    // MARK: helpers

    private func launchToTypikey() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let field = practiceField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "practice field not found")
        field.tap()
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
            practiceField(in: app).tap()
        }
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 5),
                      "Typikey home level not visible — is Typikey the active keyboard?")
        return app
    }

    private func practiceField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
    }

    private func frames(of labels: [String], in app: XCUIApplication) -> [String: CGRect] {
        var out: [String: CGRect] = [:]
        for label in labels { out[label] = app.staticTexts[label].frame }
        return out
    }

    private func assertFrames(_ baseline: [String: CGRect], in app: XCUIApplication, level: String) {
        for (label, frame) in baseline {
            let now = app.staticTexts[label].frame
            XCTAssertEqual(now.origin.x, frame.origin.x, accuracy: 1.0, "\(label) moved (x) on \(level)")
            XCTAssertEqual(now.origin.y, frame.origin.y, accuracy: 1.0, "\(label) moved (y) on \(level)")
        }
    }
}
