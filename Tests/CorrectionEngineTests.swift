import XCTest
@testable import Typikey

final class CorrectionEngineTests: XCTestCase {
    func testTranspositionBecomesSuggestionOnly() {
        let engine = CorrectionEngine(
            wordFrequencies: ["the": 100, "then": 30, "tea": 5])

        let decision = engine.evaluate(
            committedWord: "teh",
            contextBeforeWord: "I saw",
            contextAfterWord: "",
            touch: nil,
            fieldProfile: .conversational)

        guard case .suggest(let original, let replacement, let confidence) = decision else {
            return XCTFail("expected suggestion, got \(decision)")
        }
        XCTAssertEqual(original, "teh")
        XCTAssertEqual(replacement, "the")
        XCTAssertGreaterThanOrEqual(confidence, 0.5)
    }

    func testProtectedWordsAndFieldsAreIgnored() {
        let engine = CorrectionEngine(
            wordFrequencies: ["home": 100, "hello": 80],
            personalWords: ["Hafiz"])

        XCTAssertEqual(engine.evaluate(
            committedWord: "Hafiz", contextBeforeWord: "Hi", contextAfterWord: "",
            touch: nil, fieldProfile: .conversational), .ignore)
        XCTAssertEqual(engine.evaluate(
            committedWord: "HOMR", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .generic), .ignore)
        XCTAssertEqual(engine.evaluate(
            committedWord: "homr", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .url), .ignore)
        XCTAssertEqual(engine.evaluate(
            committedWord: "homr", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .email), .ignore)
        XCTAssertEqual(engine.evaluate(
            committedWord: "1234", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .generic), .ignore)
    }

    func testKnownDictionaryWordIsNeverCorrected() {
        let engine = CorrectionEngine(wordFrequencies: ["form": 10, "from": 100])
        XCTAssertEqual(engine.evaluate(
            committedWord: "form", contextBeforeWord: "fill the", contextAfterWord: "",
            touch: nil, fieldProfile: .generic), .ignore)
    }

    func testAutomaticReplacementRequiresCalibratedPrecisionGate() {
        let uncalibrated = CorrectionEngine(
            wordFrequencies: ["the": 100],
            configuration: .init(
                suggestionThreshold: 0.5,
                replacementThreshold: 0.5,
                automaticReplacementEnabled: true,
                calibratedPrecision: 0.949))
        if case .replace = uncalibrated.evaluate(
            committedWord: "teh", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .generic) {
            XCTFail("uncalibrated scorer must not replace")
        }

        let calibrated = CorrectionEngine(
            wordFrequencies: ["the": 100],
            configuration: .init(
                suggestionThreshold: 0.5,
                replacementThreshold: 0.5,
                automaticReplacementEnabled: true,
                calibratedPrecision: 0.95))
        guard case .replace(_, let replacement, _) = calibrated.evaluate(
            committedWord: "teh", contextBeforeWord: "", contextAfterWord: "",
            touch: nil, fieldProfile: .generic) else {
            return XCTFail("calibrated scorer should cross the explicit gate")
        }
        XCTAssertEqual(replacement, "the")
    }

    func testDamerauLevenshteinHandlesAdjacentTransposition() {
        XCTAssertEqual(DamerauLevenshtein.distance("teh", "the", limit: 2), 1)
        XCTAssertEqual(DamerauLevenshtein.distance("house", "mouse", limit: 2), 1)
        XCTAssertNil(DamerauLevenshtein.distance("hello", "world", limit: 2))
    }

    func testEnglishPhoneticAlternatesMatchCommonSpellings() {
        XCTAssertTrue(DoubleMetaphone.matches("night", "nite"))
        XCTAssertTrue(DoubleMetaphone.matches("phone", "fone"))
        XCTAssertFalse(DoubleMetaphone.matches("cat", "dog"))
    }

    func testEvaluationStaysWithinReverseAnalysisBudget() {
        let words = Dictionary(uniqueKeysWithValues: (0..<2_000).map {
            ("word\($0)", 2_000 - $0)
        } + [("communication", 5_000)])
        let engine = CorrectionEngine(wordFrequencies: words)
        let start = ContinuousClock.now
        _ = engine.evaluate(
            committedWord: "comunication", contextBeforeWord: "clear", contextAfterWord: "",
            touch: nil, fieldProfile: .generic)
        let components = start.duration(to: .now).components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
        XCTAssertLessThan(milliseconds, 500)
    }
}
