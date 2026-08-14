import XCTest
@testable import Typikey

final class PersonalizationSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testCurrentSnapshotRoundTrips() throws {
        let snapshot = PersonalizationSnapshot(
            version: PersonalizationSnapshot.currentVersion,
            generatedAt: now,
            words: [WeightedWord(text: "Sayfullah", weight: 0.9)],
            phrases: [WeightedPhrase(text: "go to school", weight: 0.8)],
            blockedWords: ["private"])
        let data = try snapshot.encodedData()

        XCTAssertEqual(PersonalizationSnapshot.decodeValidated(data, now: now), snapshot)
    }

    func testVersionZeroMigratesWithBlockedWordsDefault() throws {
        let generated = now.timeIntervalSinceReferenceDate
        let json = """
        {"version":0,"generatedAt":\(generated),"words":[{"text":"home","weight":1}],"phrases":[]}
        """
        let migrated = PersonalizationSnapshot.decodeValidated(Data(json.utf8), now: now)

        XCTAssertEqual(migrated?.version, PersonalizationSnapshot.currentVersion)
        XCTAssertEqual(migrated?.words, [WeightedWord(text: "home", weight: 1)])
        XCTAssertEqual(migrated?.blockedWords, [])
    }

    func testNewerTruncatedAndOversizedSnapshotsAreRejected() {
        let newer = """
        {"version":99,"generatedAt":0,"words":[],"phrases":[],"blockedWords":[]}
        """
        XCTAssertNil(PersonalizationSnapshot.decodeValidated(Data(newer.utf8), now: now))
        XCTAssertNil(PersonalizationSnapshot.decodeValidated(Data("{".utf8), now: now))
        XCTAssertNil(PersonalizationSnapshot.decodeValidated(
            Data(repeating: 0, count: PersonalizationSnapshot.maximumEncodedBytes + 1),
            now: now))
    }

    func testSnapshotOlderThanThirtyDaysIsIgnored() throws {
        let stale = PersonalizationSnapshot(
            version: PersonalizationSnapshot.currentVersion,
            generatedAt: now.addingTimeInterval(-31 * 24 * 60 * 60),
            words: [WeightedWord(text: "home", weight: 1)],
            phrases: [],
            blockedWords: [])
        XCTAssertNil(PersonalizationSnapshot.decodeValidated(
            try JSONEncoder().encode(stale), now: now))
    }

    func testBoundedSnapshotDeduplicatesAndEnforcesPayloadLimits() throws {
        let words = (0..<700).map {
            WeightedWord(text: $0 == 1 ? "HOME" : "word\($0)", weight: Double(700 - $0))
        } + [WeightedWord(text: "home", weight: 1_000)]
        let phrases = (0..<200).map {
            WeightedPhrase(text: "phrase number \($0)", weight: Double(200 - $0))
        }
        let snapshot = PersonalizationSnapshot.bounded(
            generatedAt: now,
            words: words,
            phrases: phrases,
            blockedWords: ["secret", "SECRET"])

        XCTAssertLessThanOrEqual(snapshot.words.count, 512)
        XCTAssertLessThanOrEqual(snapshot.phrases.count, 128)
        XCTAssertEqual(snapshot.words.filter { $0.text.lowercased() == "home" }.count, 1)
        XCTAssertEqual(snapshot.blockedWords, ["secret"])
        XCTAssertLessThanOrEqual(try snapshot.encodedData().count,
                                 PersonalizationSnapshot.maximumEncodedBytes)
    }

    func testInvalidTextAndWeightsAreRemovedBeforePublication() {
        let snapshot = PersonalizationSnapshot.bounded(
            generatedAt: now,
            words: [
                WeightedWord(text: String(repeating: "a", count: 65), weight: 1),
                WeightedWord(text: "valid", weight: .infinity),
                WeightedWord(text: "usable", weight: 0.5),
            ],
            phrases: [WeightedPhrase(text: String(repeating: "b", count: 241), weight: 1)],
            blockedWords: [])

        XCTAssertEqual(snapshot.words, [WeightedWord(text: "usable", weight: 0.5)])
        XCTAssertTrue(snapshot.phrases.isEmpty)
    }

    func testStorePublishesAtomicallyAndKeepsPreviousSnapshotOnFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PersonalizationSnapshotStore(directoryURL: directory)
        let original = PersonalizationSnapshot.bounded(
            generatedAt: now,
            words: [WeightedWord(text: "home", weight: 1)],
            phrases: [],
            blockedWords: [])

        try store.publish(original)
        XCTAssertEqual(store.load(now: now), original)

        let invalid = PersonalizationSnapshot(
            version: PersonalizationSnapshot.currentVersion,
            generatedAt: now,
            words: (0..<513).map { WeightedWord(text: "word\($0)", weight: 1) },
            phrases: [],
            blockedWords: [])
        XCTAssertThrowsError(try store.publish(invalid))
        XCTAssertEqual(store.load(now: now), original)

        try store.delete()
        XCTAssertNil(store.load(now: now))
    }
}
