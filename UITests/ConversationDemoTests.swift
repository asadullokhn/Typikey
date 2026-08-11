import XCTest

// The practice conversation is the whole screen-learning loop without a
// broadcast: render a chat, OCR it with the extension's own pipeline, keep
// the words. This asserts the loop end to end, including that the words a
// reply actually needs — a name and a place no dictionary carries — come
// back out.
final class ConversationDemoTests: XCTestCase {
    func testReadingTheConversationLearnsItsWords() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        let link = app.staticTexts["Practice conversation"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "practice conversation card not found")
        link.tap()

        let read = app.buttons["demoRead"]
        XCTAssertTrue(read.waitForExistence(timeout: 5), "read button not found")
        read.tap()

        let words = app.staticTexts["demoLearnedWords"]
        XCTAssertTrue(words.waitForExistence(timeout: 15), "no words came back from the reader")
        for word in ["ratna", "jurong", "satay", "hafiz"] {
            XCTAssertTrue(words.label.contains(word),
                          "expected '\(word)' from the conversation, got: \(words.label)")
        }
    }
}
