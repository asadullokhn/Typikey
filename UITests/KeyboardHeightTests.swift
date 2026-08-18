import XCTest

// Regression test for the height-growth bug: the keyboard grew on every
// open/close cycle because a root-view height constraint fed back into
// the system's cached window height. This reproduces the user-reported
// cycle (open, close, reopen, rotate) and asserts the keyboard's
// app-visible size stays put.
//
// PRECONDITION: Typikey must already be enabled on the simulator
// (Settings → General → Keyboard → Keyboards → Add New Keyboard), and the
// hardware keyboard off:
//   defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
// Enablement is per-simulator and persists, so it is a one-time step per
// device rather than a per-run one. Automating it is still unsolved — the
// AppleKeyboards defaults write is ignored by the live input system, and
// Settings-app navigation differs on iPadOS 26 (attempts preserved in
// enableTypikeyViaSettings, currently unused). That is a nuisance, not a
// blocker: with the precondition met the whole suite runs green.
//
// Measurement note: a custom keyboard does NOT surface as a `Keyboard`
// AX element, so app.keyboards is useless here. Instead we detect
// Typikey by its own "Home" pinned key, and measure the keyboard's
// effective size by where the focused text field sits — a ballooning
// keyboard window pushes the field toward the top of the screen, which
// is exactly the user-visible symptom.
final class KeyboardHeightTests: XCTestCase {

    private let tolerance: CGFloat = 60

    func testAllFourRowsFitInsideGrantedLandscapeHeight() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft

        app.focusRealKeyboard()

        let deleteWord = app.staticTexts["Delete word"]
        snapshot(name: "landscape-four-row-fit")

        XCTAssertTrue(deleteWord.waitForExistence(timeout: 3),
                      "the fourth keyboard row is clipped out of the granted height")
        XCTAssertLessThanOrEqual(deleteWord.frame.maxY, app.frame.maxY + 1,
                                 "the fourth keyboard row extends below the visible screen")
    }

    func testKeyboardSizeStableAcrossCyclesAndRotation() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        app.focusRealKeyboard()

        // A newly enabled third-party keyboard triggers a one-time system
        // education sheet ("Quickly Change Keyboards") that blocks input.
        let screenHeight = XCUIScreen.main.screenshot().image.size.height

        let baseline = practiceField(in: app).frame.maxY
        snapshot(name: "open-1-baseline")
        // The practice field is the first card now, and the scroll view
        // parks it just under the navigation bar when the keyboard opens,
        // so its absolute position is naturally high. What still cannot
        // happen is the field being pushed off the top entirely, which is
        // what a ballooning keyboard window did. The drift assertions
        // below are the real regression guard.
        XCTAssertGreaterThan(baseline, screenHeight * 0.1,
                             "field crushed to the top on first open — keyboard window oversized")

        // The reported reproduction: open, close, open again, repeatedly.
        for cycle in 1...3 {
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 1)
            app.activate()
            if !app.staticTexts["Home"].waitForExistence(timeout: 3) {
                practiceField(in: app).tap()
            }
            let position = practiceField(in: app).frame.maxY
            snapshot(name: "cycle-\(cycle)")
            XCTAssertEqual(position, baseline, accuracy: tolerance,
                           "keyboard size drifted on cycle \(cycle): field at \(baseline) → \(position)")
        }

        // Rotation both ways; after returning to portrait the field must
        // sit where it started.
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        snapshot(name: "landscape")
        XCTAssertTrue(app.staticTexts["Home"].exists, "Typikey lost after rotation")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        let back = practiceField(in: app).frame.maxY
        snapshot(name: "back-to-portrait")
        XCTAssertEqual(back, baseline, accuracy: tolerance,
                       "keyboard size did not recover after rotation: field at \(baseline) → \(back)")

        // One more open/close after rotating — the compound case.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.activate()
        if !app.staticTexts["Home"].waitForExistence(timeout: 3) {
            practiceField(in: app).tap()
        }
        let final = practiceField(in: app).frame.maxY
        snapshot(name: "final")
        XCTAssertEqual(final, baseline, accuracy: tolerance,
                       "keyboard size drifted after rotation + reopen: field at \(baseline) → \(final)")
    }

    // SwiftUI's multiline TextField can surface as either element type.
    private func practiceField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
    }

    /// Unused: preserved documentation of the enablement-automation
    /// attempts. See the header comment for why this is manual for now.
    private func enableTypikeyViaSettings() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let general = settings.staticTexts["General"].firstMatch
        guard general.waitForExistence(timeout: 10) else { return }
        general.tap()
        let keyboardRow = settings.staticTexts["Keyboard"].firstMatch
        guard keyboardRow.waitForExistence(timeout: 5) else { return }
        keyboardRow.tap()
        let keyboardsRow = settings.staticTexts["Keyboards"].firstMatch
        guard keyboardsRow.waitForExistence(timeout: 5) else { return }
        keyboardsRow.tap()
        if settings.staticTexts["Typikey"].waitForExistence(timeout: 2) {
            settings.terminate()
            return
        }
        let addNew = settings.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
        guard addNew.waitForExistence(timeout: 5) else { return }
        addNew.tap()
        let bigKeys = settings.staticTexts["Typikey"].firstMatch
        if bigKeys.waitForExistence(timeout: 5) {
            bigKeys.tap()
        }
        settings.terminate()
    }

    private func snapshot(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
