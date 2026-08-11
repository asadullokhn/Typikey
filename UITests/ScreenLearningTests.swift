import XCTest

// A broadcast can only be started by a human through the system picker
// (there is no programmatic start, by design), so the automatable surface
// is the card and its self-test: the card must be on the home screen, and
// "Test the reader" must run the SAME Vision + tokenizer path the
// broadcast extension uses and report words back. That covers everything
// in the OCR pipeline except ReplayKit's frame delivery.
final class ScreenLearningTests: XCTestCase {
    func testScreenLearningCardIsInSetup() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        let title = app.staticTexts["Learn from my screen"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "screen-learning card should be in Setup")
    }

    func testReaderSelfTestExtractsWords() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        // The reader test lives in the Diagnostics drawer — troubleshooting,
        // not daily use — so open that first.
        app.swipeUp()
        let diagnostics = app.staticTexts["Diagnostics"]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 5), "Diagnostics section not found")
        diagnostics.tap()

        let button = app.buttons["screenSelfTest"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "self-test button not found")
        button.tap()

        let result = app.staticTexts["screenSelfTestResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 15), "self-test produced no result")
        let text = result.label
        XCTAssertTrue(text.hasPrefix("Reader works."),
                      "OCR pipeline failed on this device: \(text)")
        // The rendered sample is "Ratna is bringing pizza to Singapore on
        // Friday"; these survive the 3-char/stopword/digit filters.
        for word in ["ratna", "pizza", "singapore", "friday"] {
            XCTAssertTrue(text.contains(word), "expected '\(word)' in reader output: \(text)")
        }
    }
}
