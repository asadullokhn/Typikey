import XCTest
@testable import Typikey

private final class MissingDocumentIdentifierObject: NSObject {
    @objc dynamic var documentIdentifier: NSUUID? { nil }
}

private final class AvailableDocumentIdentifierObject: NSObject {
    private let storedIdentifier: NSUUID

    init(identifier: UUID) {
        storedIdentifier = identifier as NSUUID
    }

    @objc dynamic var documentIdentifier: NSUUID { storedIdentifier }
}

final class TextDocumentIdentityTests: XCTestCase {
    func testMissingObjectiveCDocumentIdentifierReturnsNil() {
        XCTAssertNil(TextDocumentIdentity.read(from: MissingDocumentIdentifierObject()))
    }

    func testAvailableObjectiveCDocumentIdentifierReturnsUUID() {
        let identifier = UUID()

        XCTAssertEqual(
            TextDocumentIdentity.read(from: AvailableDocumentIdentifierObject(identifier: identifier)),
            identifier)
    }
}
