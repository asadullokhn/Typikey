import XCTest

// Invariant 9, restored to Keiko's reference: controls pin both edges of
// the word board. Home / Categories / Clear / Delete word occupy the left;
// ABC, double-height Enter, and Hide keyboard occupy the right. The eight
// content columns between them make ten equal 1:1 columns on a 12.9-inch
// iPad.
// Word keys surface as buttons containing labels. Target the button when a
// suggestion can repeat the same word in a second static-text element.
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
    private let leftLabels = ["Home", "Categories", "Clear", "Delete word"]

    func testPinnedKeysIdenticalAcrossLevels() {
        let app = launchToTypikey()

        let baseline = frames(of: leftLabels, in: app)
        for (label, frame) in baseline {
            XCTAssertFalse(frame.isEmpty, "\(label) missing on home level")
            XCTAssertLessThan(frame.midX, app.frame.width / 2,
                              "\(label) belongs to the LEFT pinned column")
            XCTAssertEqual(frame.minX, baseline["Home"]?.minX ?? frame.minX, accuracy: 1,
                           "\(label) must align with Home on the left edge")
        }

        let abc = app.staticTexts["ABC"]
        XCTAssertTrue(abc.exists, "ABC missing from the right edge")
        XCTAssertGreaterThan(abc.frame.midX, app.frame.width * 0.9,
                             "ABC belongs to the RIGHT pinned column")
        let enter = app.staticTexts["Enter"]
        XCTAssertTrue(enter.exists, "Enter missing from the right edge")
        XCTAssertEqual(enter.frame.minX, abc.frame.minX, accuracy: 1,
                       "Enter must align with ABC on the right edge")
        XCTAssertEqual(enter.frame.height, abc.frame.height * 2 + 6, accuracy: 12,
                       "Enter must span the middle two rows")

        app.staticTexts["Categories"].tap()
        assertFrames(baseline, in: app, level: "categories")

        app.staticTexts["Core"].tap()
        assertFrames(baseline, in: app, level: "words")

        app.staticTexts["Home"].tap()
        app.staticTexts["ABC"].tap()
        assertFrames(baseline, in: app, level: "letters")

        let toNumbers = app.staticTexts.matching(identifier: "123").allElementsBoundByIndex
            .filter(\.exists)
            .max { $0.frame.midX < $1.frame.midX }
        XCTAssertNotNil(toNumbers, "no 123 key on the letters board")
        toNumbers?.tap()
        assertFrames(baseline, in: app, level: "numbers")
    }

    func testEveryBuiltInCategoryKeepsTypikeyActive() {
        let app = launchToTypikey()
        let categories = [
            ("Core", "want"),
            ("People", "Mum"),
            ("Actions", "eat"),
            ("Feelings", "happy"),
            ("Food", "water"),
            ("Places", "home"),
            ("Art", "draw"),
            ("Web", "search"),
            ("Chat", "hello"),
            ("Little words", "to"),
        ]

        for (categoryName, visibleWord) in categories {
            app.staticTexts["Categories"].tap()
            let category = app.staticTexts[categoryName]
            XCTAssertTrue(category.waitForExistence(timeout: 3),
                          "\(categoryName) category is missing")
            category.tap()
            XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 3),
                          "opening \(categoryName) removed the Typikey extension")
            XCTAssertTrue(app.staticTexts[visibleWord].firstMatch.exists,
                          "\(categoryName) did not show its vocabulary")
        }
    }

    // The edge controls are keyboard furniture, laid down independently
    // from page content so no word can overwrite them.
    func testGridControlsPresentOnWordBoards() {
        let app = launchToTypikey()
        for level in ["home", "categories"] {
            XCTAssertTrue(app.staticTexts["Hide keyboard"].exists
                            || app.staticTexts["Hide\nkeyboard"].exists,
                          "hide-keyboard missing on \(level)")
            XCTAssertTrue(app.staticTexts["Cursor right"].exists, "cursor-right missing on \(level)")
            XCTAssertTrue(app.staticTexts["Enter"].exists || app.staticTexts["Done"].exists
                            || app.staticTexts["Go"].exists || app.staticTexts["Send"].exists
                            || app.staticTexts["Search"].exists,
                          "Enter missing on \(level)")
            if level == "home" { app.staticTexts["Categories"].tap() }
        }
    }

    func testRemovedKeyboardSwitcherSlotContainsAWordWithoutMovingTheFrame() {
        let app = launchToTypikey()

        XCTAssertFalse(app.buttons["Change keyboard"].exists,
                       "the keyboard-switch button must be removed")
        let deleteWord = app.staticTexts["Delete word"]
        XCTAssertTrue(deleteWord.exists, "the left edge column must not move")
        guard let bottomRowWord = gridText("that", in: app) else {
            return XCTFail("the Home board words are missing")
        }
        XCTAssertEqual(bottomRowWord.frame.midY, deleteWord.frame.midY, accuracy: 12,
                       "words must reach the bottom row of the content grid")
        // The two bottom corners are the cursor keys on every board, which
        // is what the app's page model has always reserved.
        XCTAssertTrue(app.staticTexts["Cursor left"].exists,
                      "the bottom-left content control must not move")
        XCTAssertTrue(app.staticTexts["Cursor right"].exists,
                      "the bottom-right content control must not move")
        XCTAssertGreaterThan(app.staticTexts["ABC"].frame.midX, app.frame.width * 0.9,
                             "the right edge column must not move")
    }

    // Both cursor keys sit in the bottom corners of every board (19 Aug
    // 2026); ⌫ belongs only to the levels where characters are typed.
    func testCharacterToolsLiveOnTheTypingLevels() {
        let app = launchToTypikey()
        XCTAssertTrue(app.staticTexts["Cursor left"].exists, "cursor-left pins the bottom-left")
        XCTAssertFalse(app.staticTexts["⌫"].exists, "no single-character delete on a word board")
        app.staticTexts["ABC"].tap()
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 3), "letters level did not open")
        XCTAssertTrue(app.staticTexts["⌫"].exists, "single-character delete missing on letters")
        XCTAssertTrue(app.staticTexts["Cursor left"].exists, "cursor-left missing on letters")
    }

    func testVisibleWordTapInsertsWord() {
        let app = launchToTypikey()
        let field = practiceField(in: app)
        let before = field.value as? String ?? ""
        let wordKey = app.buttons["typikeySuggestion0"]
        XCTAssertTrue(wordKey.waitForExistence(timeout: 3),
                      "the first visible word candidate is not addressable")
        let tappedWord = wordKey.label
        wordKey.tap()
        let value = field.value as? String ?? ""
        XCTAssertNotEqual(value, before, "tapping a word candidate should change the field")
        XCTAssertTrue(value.localizedCaseInsensitiveContains(tappedWord),
                      "tapping '\(tappedWord)' should insert that word, got: \(value)")
    }

    // Clear erases on one tap (team decision, 18 Aug 2026). It used to arm
    // first and relabel to "tap again".
    func testClearAllErasesOnOneTap() {
        let app = launchToTypikey()
        // "want" is also a suggestion chip; the grid key is the lower match.
        gridText("want", in: app)?.tap()
        var value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("Want"), "setup: word not inserted")

        app.staticTexts["Clear"].tap()
        value = practiceField(in: app).value as? String ?? ""
        XCTAssertFalse(value.contains("Want"), "one tap should clear the text")
        XCTAssertFalse(app.staticTexts["tap again"].exists,
                       "Clear no longer arms, so it must never relabel")
    }

    func testManualLevelSurvivesReshow() {
        let app = launchToTypikey()
        app.staticTexts["ABC"].tap()
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
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        app.focusRealKeyboard()
        return app
    }

    private func practiceField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
    }

    private func gridText(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        app.staticTexts.matching(identifier: label).allElementsBoundByIndex
            .filter(\.exists)
            .max { $0.frame.minY < $1.frame.minY }
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
