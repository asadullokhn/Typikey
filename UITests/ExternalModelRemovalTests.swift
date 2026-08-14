import XCTest

final class ExternalModelRemovalTests: XCTestCase {
    func testSetupOffersNoRemoteModelOrCredentialControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding"]
        app.launch()
        app.openSetup()

        let remoteModelToggle = app.switches["aiAssistToggle"]
        for _ in 0..<4 where !remoteModelToggle.exists {
            app.swipeUp()
        }

        XCTAssertFalse(remoteModelToggle.exists,
                       "Setup must not offer remote model controls")
        XCTAssertFalse(app.staticTexts["Suggestions from an AI model"].exists,
                       "Setup must not advertise hosted suggestions")
        XCTAssertFalse(app.staticTexts["API key saved"].exists,
                       "Setup must not expose saved API credentials")
        XCTAssertFalse(app.staticTexts["No API key"].exists,
                       "Setup must not request API credentials")
    }
}
