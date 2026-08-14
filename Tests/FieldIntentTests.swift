import UIKit
import XCTest
@testable import Typikey

final class FieldIntentTests: XCTestCase {
    func testURLKeyboardUsesURLProfile() {
        XCTAssertEqual(FieldProfile(
            keyboardType: .URL,
            returnKeyType: .default,
            textContentType: nil), .url)
    }

    func testEmailKeyboardUsesEmailProfile() {
        XCTAssertEqual(FieldProfile(
            keyboardType: .emailAddress,
            returnKeyType: .default,
            textContentType: .emailAddress), .email)
    }

    func testSearchKeyboardUsesSearchProfile() {
        XCTAssertEqual(FieldProfile(
            keyboardType: .webSearch,
            returnKeyType: .search,
            textContentType: nil), .search)
    }

    func testSendReturnKeyUsesConversationalProfile() {
        XCTAssertEqual(FieldProfile(
            keyboardType: .default,
            returnKeyType: .send,
            textContentType: nil), .conversational)
    }

    func testUnsupportedTraitsUseGenericProfile() {
        XCTAssertEqual(FieldProfile(
            keyboardType: .asciiCapable,
            returnKeyType: .done,
            textContentType: nil), .generic)
    }
}
