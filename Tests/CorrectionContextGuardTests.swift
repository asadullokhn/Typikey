import XCTest
@testable import Typikey

final class CorrectionContextGuardTests: XCTestCase {
    func testApplyRequiresSameDocumentAndExactOriginalSuffix() {
        let document = UUID()
        XCTAssertTrue(CorrectionContextGuard.canApply(
            documentIdentifier: document,
            currentSuffix: "I saw teh ",
            expectedDocumentIdentifier: document,
            expectedSuffix: "teh "))
        XCTAssertFalse(CorrectionContextGuard.canApply(
            documentIdentifier: UUID(),
            currentSuffix: "I saw teh ",
            expectedDocumentIdentifier: document,
            expectedSuffix: "teh "))
        XCTAssertFalse(CorrectionContextGuard.canApply(
            documentIdentifier: document,
            currentSuffix: "I saw them ",
            expectedDocumentIdentifier: document,
            expectedSuffix: "teh "))
        XCTAssertFalse(CorrectionContextGuard.canApply(
            documentIdentifier: nil,
            currentSuffix: "I saw teh ",
            expectedDocumentIdentifier: document,
            expectedSuffix: "teh "))
    }

    func testUndoRequiresSameDocumentAndExactReplacementSuffix() {
        let document = UUID()
        let correction = AppliedCorrection(
            original: "teh",
            replacement: "the",
            documentIdentifier: document,
            expectedContextSuffix: "the ")

        XCTAssertTrue(CorrectionContextGuard.canUndo(
            correction, documentIdentifier: document, currentSuffix: "I saw the "))
        XCTAssertFalse(CorrectionContextGuard.canUndo(
            correction, documentIdentifier: document, currentSuffix: "I saw the cat "))
        XCTAssertFalse(CorrectionContextGuard.canUndo(
            correction, documentIdentifier: UUID(), currentSuffix: "I saw the "))
        XCTAssertFalse(CorrectionContextGuard.canUndo(
            correction, documentIdentifier: nil, currentSuffix: "I saw the "))
    }
}
