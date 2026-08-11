import XCTest

/// The question key as a repair, not just a character.
///
/// "I play you" is three taps and clear to anyone who knows him; it is
/// also not a sentence. Pressing `?` offers the sentence he would have
/// written with unlimited time — but only offers it, which is the half of
/// this feature worth testing hardest. A rewrite that happened on its own
/// would sometimes destroy four minutes of work.
final class RephraseTests: XCTestCase {

    func testTheQuestionKeyOffersARephrasing() {
        let app = launchToKeyboard()
        gridKey(app, "I")?.tap()
        gridKey(app, "play")?.tap()
        gridKey(app, "you")?.tap()
        gridKey(app, "?")?.tap()

        let offer = app.staticTexts["Do you want to play with me?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5),
                      "the question key should offer a rephrasing of what he wrote")

        // Nothing has changed until he says so.
        XCTAssertEqual(normalise(fieldText(app)), "i play you",
                       "the sentence must not be rewritten before he accepts")

        offer.tap()
        XCTAssertEqual(normalise(fieldText(app)), "do you want to play with me",
                       "tapping the chip should replace the sentence")
    }

    /// His own words are always among the options. Every rephrasing is a
    /// guess about intent, and a guess he cannot decline is a guess made
    /// for him.
    func testHisOwnSentenceIsAlwaysOffered() {
        let app = launchToKeyboard()
        gridKey(app, "I")?.tap()
        gridKey(app, "want")?.tap()
        gridKey(app, "?")?.tap()
        XCTAssertTrue(app.staticTexts["I want?"].waitForExistence(timeout: 5),
                      "the literal sentence must always be one of the options")
    }

    /// The offer belongs to one deliberate act. Typing again means he is
    /// still writing, and the bar goes back to predicting words.
    func testTypingOnClearsTheOffer() {
        let app = launchToKeyboard()
        gridKey(app, "I")?.tap()
        gridKey(app, "play")?.tap()
        gridKey(app, "you")?.tap()
        gridKey(app, "?")?.tap()
        XCTAssertTrue(app.staticTexts["Do you want to play with me?"].waitForExistence(timeout: 5),
                      "setup: no rephrasing was offered")

        gridKey(app, "yes")?.tap()
        XCTAssertFalse(app.staticTexts["Do you want to play with me?"].exists,
                       "writing another word should end the offer")
    }

    // MARK: helpers

    private func fieldText(_ app: XCUIApplication) -> String {
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        return (field.value as? String) ?? ""
    }

    private func normalise(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// A label can appear both as a suggestion chip and as a grid key. The
    /// grid sits below the suggestion bar, so the lowest match is the key.
    private func gridKey(_ app: XCUIApplication, _ label: String) -> XCUIElement? {
        let matches = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label))
        guard matches.count > 0 else { return nil }
        return (0..<matches.count)
            .map { matches.element(boundBy: $0) }
            .filter(\.exists)
            .max { $0.frame.minY < $1.frame.minY }
    }

    private func launchToKeyboard() -> XCUIApplication {
        let app = XCUIApplication()
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
