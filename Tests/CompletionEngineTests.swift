import XCTest
@testable import Typikey

private actor FieldProfileRecorder {
    private var value: FieldProfile?

    func record(_ profile: FieldProfile) {
        value = profile
    }

    func recordedValue() -> FieldProfile? {
        value
    }
}

@MainActor
final class CompletionEngineTests: XCTestCase {
    func testInjectedProviderReceivesFieldProfileAndReturnsSanitizedWords() async {
        let delivered = expectation(description: "completion delivered")
        let profileRecorder = FieldProfileRecorder()
        let engine = CompletionEngine(
            responseProvider: { _, profile in
                await profileRecorder.record(profile)
                return ["go home please!"]
            },
            debounceInterval: 0,
            timeout: 0.1)

        engine.requestCompletion(
            context: "I want to",
            vocabulary: ["home"],
            fieldProfile: .conversational
        ) { completion in
            XCTAssertEqual(completion?.words, ["go", "home", "please"])
            delivered.fulfill()
        }

        await fulfillment(of: [delivered], timeout: 1)
        let receivedProfile = await profileRecorder.recordedValue()
        XCTAssertEqual(receivedProfile, .conversational)
        guard case .available(let words, _) = engine.lastOutcome else {
            return XCTFail("expected an available outcome")
        }
        XCTAssertEqual(words, ["go", "home", "please"])
    }

    func testNewRequestSuppressesStaleResult() async throws {
        let delivered = expectation(description: "latest completion delivered")
        var results: [[String]] = []
        let engine = CompletionEngine(
            responseProvider: { prompt, _ in
                if prompt.contains("first") {
                    try await Task.sleep(for: .milliseconds(100))
                    return ["stale answer"]
                }
                return ["latest answer"]
            },
            debounceInterval: 0,
            timeout: 0.5)

        engine.requestCompletion(context: "first", vocabulary: []) { completion in
            if let words = completion?.words { results.append(words) }
        }
        try await Task.sleep(for: .milliseconds(10))
        engine.requestCompletion(context: "second", vocabulary: []) { completion in
            if let words = completion?.words { results.append(words) }
            delivered.fulfill()
        }

        await fulfillment(of: [delivered], timeout: 1)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(results, [["latest", "answer"]])
    }

    func testTwoTimeoutsDegradeForTheKeyboardSession() async {
        let engine = CompletionEngine(
            responseProvider: { _, _ in
                try await Task.sleep(for: .seconds(1))
                return ["late"]
            },
            debounceInterval: 0,
            timeout: 0.01)

        for index in 0..<2 {
            let delivered = expectation(description: "timeout \(index)")
            engine.requestCompletion(context: "hello", vocabulary: []) { completion in
                XCTAssertNil(completion)
                delivered.fulfill()
            }
            await fulfillment(of: [delivered], timeout: 1)
        }

        XCTAssertTrue(engine.isDegraded)
        XCTAssertEqual(engine.lastOutcome, .timedOut)
    }
}
