import XCTest
@testable import Typikey

final class PredictionTypesTests: XCTestCase {
    func testCandidateIdentityIsCaseInsensitiveWithoutChangingDisplayText() {
        let candidate = PredictionCandidate(
            text: "Home",
            score: 1,
            source: .personal)

        XCTAssertEqual(candidate.identity, "home")
        XCTAssertEqual(candidate.text, "Home")
    }

    func testResultHonorsCandidateLimit() {
        let candidates = (0..<5).map {
            PredictionCandidate(text: "word\($0)", score: Double($0), source: .prefix)
        }

        let result = PredictionResult(
            candidates: candidates,
            generatedAt: .now,
            maximumCandidates: 3)

        XCTAssertEqual(result.candidates.count, 3)
    }
}
