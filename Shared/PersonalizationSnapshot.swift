import Foundation

struct WeightedWord: Codable, Equatable, Sendable {
    let text: String
    let weight: Double
}

struct WeightedPhrase: Codable, Equatable, Sendable {
    let text: String
    let weight: Double
}

struct PersonalizationSnapshot: Codable, Equatable, Sendable {
    enum SnapshotError: Error {
        case oversized
        case invalid
    }

    static let currentVersion = 1
    static let maximumEncodedBytes = 256 * 1_024
    static let maximumAge: TimeInterval = 30 * 24 * 60 * 60
    static let fileName = "personalization-snapshot.json"

    let version: Int
    let generatedAt: Date
    let words: [WeightedWord]
    let phrases: [WeightedPhrase]
    let blockedWords: [String]

    static func bounded(generatedAt: Date = .now,
                        words: [WeightedWord],
                        phrases: [WeightedPhrase],
                        blockedWords: [String]) -> PersonalizationSnapshot {
        let blocked = uniqueStrings(blockedWords, maximumLength: 64, limit: 512)
            .map { $0.lowercased() }
        let blockedSet = Set(blocked)
        let boundedWords = uniqueWeightedWords(words)
            .filter { !blockedSet.contains($0.text.lowercased()) }
            .prefix(512)
        let boundedPhrases = uniqueWeightedPhrases(phrases)
            .prefix(128)
        return PersonalizationSnapshot(
            version: currentVersion,
            generatedAt: generatedAt,
            words: Array(boundedWords),
            phrases: Array(boundedPhrases),
            blockedWords: blocked)
    }

    func encodedData() throws -> Data {
        guard isStructurallyValid else { throw SnapshotError.invalid }
        let data = try JSONEncoder().encode(self)
        guard data.count <= Self.maximumEncodedBytes else { throw SnapshotError.oversized }
        return data
    }

    static func decodeValidated(_ data: Data, now: Date = .now) -> PersonalizationSnapshot? {
        guard data.count <= maximumEncodedBytes,
              let decoded = try? JSONDecoder().decode(PersonalizationSnapshot.self, from: data),
              decoded.version == 0 || decoded.version == currentVersion else { return nil }
        let migrated = decoded.version == 0
            ? PersonalizationSnapshot(
                version: currentVersion,
                generatedAt: decoded.generatedAt,
                words: decoded.words,
                phrases: decoded.phrases,
                blockedWords: decoded.blockedWords)
            : decoded
        guard migrated.isStructurallyValid,
              now.timeIntervalSince(migrated.generatedAt) >= -300,
              now.timeIntervalSince(migrated.generatedAt) <= maximumAge else { return nil }
        return migrated
    }

    static func load(from url: URL, now: Date = .now) -> PersonalizationSnapshot? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        return decodeValidated(data, now: now)
    }

    private var isStructurallyValid: Bool {
        guard version == Self.currentVersion || version == 0,
              words.count <= 512,
              phrases.count <= 128,
              blockedWords.count <= 512 else { return false }
        return words.allSatisfy {
            !$0.text.isEmpty && $0.text.count <= 64 && $0.weight.isFinite && $0.weight > 0
        } && phrases.allSatisfy {
            !$0.text.isEmpty && $0.text.count <= 240 && $0.weight.isFinite && $0.weight > 0
        } && blockedWords.allSatisfy { !$0.isEmpty && $0.count <= 64 }
    }

    private static func uniqueWeightedWords(_ input: [WeightedWord]) -> [WeightedWord] {
        var best: [String: WeightedWord] = [:]
        for item in input {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 64, item.weight.isFinite, item.weight > 0 else { continue }
            let identity = text.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if item.weight > (best[identity]?.weight ?? -.infinity) {
                best[identity] = WeightedWord(text: text, weight: item.weight)
            }
        }
        return best.values.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
        }
    }

    private static func uniqueWeightedPhrases(_ input: [WeightedPhrase]) -> [WeightedPhrase] {
        var best: [String: WeightedPhrase] = [:]
        for item in input {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 240, item.weight.isFinite, item.weight > 0 else { continue }
            let identity = text.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if item.weight > (best[identity]?.weight ?? -.infinity) {
                best[identity] = WeightedPhrase(text: text, weight: item.weight)
            }
        }
        return best.values.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
        }
    }

    private static func uniqueStrings(_ input: [String],
                                      maximumLength: Int,
                                      limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in input {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maximumLength else { continue }
            let identity = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(identity).inserted else { continue }
            result.append(trimmed)
            if result.count == limit { break }
        }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case generatedAt
        case words
        case phrases
        case blockedWords
    }

    init(version: Int,
         generatedAt: Date,
         words: [WeightedWord],
         phrases: [WeightedPhrase],
         blockedWords: [String]) {
        self.version = version
        self.generatedAt = generatedAt
        self.words = words
        self.phrases = phrases
        self.blockedWords = blockedWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        words = try container.decodeIfPresent([WeightedWord].self, forKey: .words) ?? []
        phrases = try container.decodeIfPresent([WeightedPhrase].self, forKey: .phrases) ?? []
        blockedWords = try container.decodeIfPresent([String].self, forKey: .blockedWords) ?? []
    }
}

struct PersonalizationSnapshotStore: Sendable {
    let directoryURL: URL

    var snapshotURL: URL {
        directoryURL.appendingPathComponent(PersonalizationSnapshot.fileName, isDirectory: false)
    }

    func load(now: Date = .now) -> PersonalizationSnapshot? {
        PersonalizationSnapshot.load(from: snapshotURL, now: now)
    }

    func publish(_ snapshot: PersonalizationSnapshot) throws {
        let data = try snapshot.encodedData()
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL, withIntermediateDirectories: true)
        let temporaryURL = directoryURL.appendingPathComponent(
            ".personalization-\(UUID().uuidString).tmp", isDirectory: false)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        try data.write(to: temporaryURL)
        if fileManager.fileExists(atPath: snapshotURL.path) {
            _ = try fileManager.replaceItemAt(
                snapshotURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly])
        } else {
            try fileManager.moveItem(at: temporaryURL, to: snapshotURL)
        }
    }

    func delete() throws {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        try FileManager.default.removeItem(at: snapshotURL)
    }
}
