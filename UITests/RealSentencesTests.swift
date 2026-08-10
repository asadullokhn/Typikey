import XCTest

/// Not a pass/fail test — a measurement.
///
/// Every other test here asserts an invariant. This one asks the question
/// that actually decides whether Typikey is worth using: take a sentence
/// somebody would really send — to ChatGPT, to Mum, to a friend — and find
/// out what it costs to say it.
///
/// For each word it records where the word came from and what it cost:
///
///   - **board**   one tap, the word was on the page in front of him
///   - **spelled** the word is on no board, so it was typed letter by
///                 letter: two taps for abc and Home, plus one per letter
///
/// Then it reads back what actually landed in the field, because a cheap
/// sentence that comes out ungrammatical is not a cheap sentence.
///
/// At 30 seconds a tap — Sayfullah's worst case — every tap in the total
/// is half a minute of someone's life, so the numbers are the point.
final class RealSentencesTests: XCTestCase {

    private let sentences: [(who: String, text: String)] = [
        ("ChatGPT",  "can you write a story about a monster"),
        ("Mum",      "i want to eat rice now"),
        ("a friend", "yesterday i went to the park with my friend"),
        ("Dad",      "what time is dinner"),
        ("ChatGPT",  "please help me with my homework"),
        ("a friend", "i am going to watch a video"),
    ]

    func testWhatRealSentencesCost() {
        let app = launchToKeyboard()
        var report = ["# What a real sentence costs", ""]
        var totalTaps = 0
        var totalSpelled = 0
        var mismatches: [String] = []

        for sentence in sentences {
            clearField(app)
            var taps = 0
            var spelled: [String] = []

            for word in sentence.text.split(separator: " ").map(String.init) {
                if let key = gridKey(app, word) {
                    key.tap()
                    taps += 1
                } else {
                    spell(word, in: app)
                    taps += word.count + 2
                    spelled.append(word)
                }
            }

            let produced = normalise(fieldText(app))
            let wanted = normalise(sentence.text)
            let matched = produced == wanted
            if !matched { mismatches.append("\(sentence.text)  ->  \(produced)") }

            totalTaps += taps
            totalSpelled += spelled.count
            report.append("""
            **To \(sentence.who):** "\(sentence.text)"
            - \(taps) taps (\(sentence.text.count) typing it letter by letter)
            - off-board, had to be spelled: \(spelled.isEmpty ? "none" : spelled.joined(separator: ", "))
            - came out as: "\(produced)"\(matched ? "" : "  ← DIFFERENT")
            """)
            report.append("")
        }

        let letterByLetter = sentences.reduce(0) { $0 + $1.text.count }
        report.append("## Totals")
        report.append("- \(totalTaps) taps against \(letterByLetter) letter by letter")
        report.append("- \(totalSpelled) words were on no board and had to be spelled")
        report.append("- \(mismatches.count) of \(sentences.count) sentences came out different:")
        report.append(contentsOf: mismatches.map { "  - \($0)" })

        let text = report.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "sentence-cost"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("\n" + text + "\n")

        // The bar is deliberately low: this exists to measure, not to gate.
        // It fails only if the board is worse than spelling everything,
        // which would mean the whole idea is not working.
        XCTAssertLessThan(totalTaps, letterByLetter,
                          "the grid should cost fewer taps than typing every letter")
    }

    // MARK: driving

    private func spell(_ word: String, in app: XCUIApplication) {
        if app.staticTexts["abc"].exists { app.staticTexts["abc"].tap() }
        for letter in word.lowercased() {
            let key = app.staticTexts[String(letter)].firstMatch
            if key.waitForExistence(timeout: 2) { key.tap() }
        }
        if app.staticTexts["space"].exists { app.staticTexts["space"].tap() }
        if app.staticTexts["Home"].exists { app.staticTexts["Home"].tap() }
    }

    private func clearField(_ app: XCUIApplication) {
        guard app.staticTexts["Clear"].exists else { return }
        app.staticTexts["Clear"].tap()
        if app.staticTexts["tap again"].waitForExistence(timeout: 2) {
            app.staticTexts["tap again"].tap()
        }
    }

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

    /// The grid sits below the suggestion bar, so the lowest match is the
    /// key rather than a chip offering the same word.
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
