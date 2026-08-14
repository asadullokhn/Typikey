import XCTest
@testable import Typikey

final class PredictionRankerTests: XCTestCase {
    func testRankerDeduplicatesCaseInsensitivelyAndKeepsBestDisplayText() {
        let ranked = PredictionRanker().rank([
            PredictionCandidate(text: "home", score: 1, source: .seedNGram),
            PredictionCandidate(text: "Home", score: 1, source: .personal),
        ], limit: 3)

        XCTAssertEqual(ranked.map(\.text), ["Home"])
        XCTAssertEqual(ranked.first?.source, .personal)
    }

    func testRankerNormalizesEachSourceBeforeApplyingWeights() {
        let ranked = PredictionRanker().rank([
            PredictionCandidate(text: "personal", score: 2, source: .personal),
            PredictionCandidate(text: "seed", score: 100, source: .seedNGram),
        ], limit: 3)

        XCTAssertEqual(ranked.map(\.text), ["personal", "seed"])
    }

    func testRankerRejectsNonFiniteAndNonPositiveScores() {
        let ranked = PredictionRanker().rank([
            PredictionCandidate(text: "nan", score: .nan, source: .prefix),
            PredictionCandidate(text: "infinite", score: .infinity, source: .prefix),
            PredictionCandidate(text: "zero", score: 0, source: .prefix),
            PredictionCandidate(text: "valid", score: 1, source: .prefix),
        ], limit: 3)

        XCTAssertEqual(ranked.map(\.text), ["valid"])
    }

    func testRankerUsesInputOrderForExactTiesAndHonorsLimit() {
        let ranked = PredictionRanker().rank([
            PredictionCandidate(text: "first", score: 1, source: .prefix),
            PredictionCandidate(text: "second", score: 1, source: .prefix),
            PredictionCandidate(text: "third", score: 1, source: .prefix),
        ], limit: 2)

        XCTAssertEqual(ranked.map(\.text), ["first", "second"])
    }
}
