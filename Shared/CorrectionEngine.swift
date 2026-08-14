import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CorrectionFeatures: Equatable, Sendable {
    let spatial: Double
    let language: Double
    let editSimilarity: Double
    let phonetic: Double
    let personalFrequency: Double
}

enum CorrectionDecision: Equatable, Sendable {
    case ignore
    case suggest(original: String, replacement: String, confidence: Double)
    case replace(original: String, replacement: String, confidence: Double)
}

struct AppliedCorrection: Equatable, Sendable {
    let original: String
    let replacement: String
    let documentIdentifier: UUID
    let expectedContextSuffix: String
}

enum CorrectionContextGuard {
    static func canApply(documentIdentifier: UUID?,
                         currentSuffix: String,
                         expectedDocumentIdentifier: UUID,
                         expectedSuffix: String) -> Bool {
        guard let documentIdentifier else { return false }
        return documentIdentifier == expectedDocumentIdentifier
            && currentSuffix.hasSuffix(expectedSuffix)
    }

    static func canUndo(_ correction: AppliedCorrection,
                        documentIdentifier: UUID?,
                        currentSuffix: String) -> Bool {
        canApply(
            documentIdentifier: documentIdentifier,
            currentSuffix: currentSuffix,
            expectedDocumentIdentifier: correction.documentIdentifier,
            expectedSuffix: correction.expectedContextSuffix)
    }
}

struct CorrectionEngine: Sendable {
    struct Configuration: Equatable, Sendable {
        let suggestionThreshold: Double
        let replacementThreshold: Double
        let automaticReplacementEnabled: Bool
        let calibratedPrecision: Double

        init(suggestionThreshold: Double = 0.50,
             replacementThreshold: Double = 0.82,
             automaticReplacementEnabled: Bool = false,
             calibratedPrecision: Double = 0) {
            self.suggestionThreshold = suggestionThreshold
            self.replacementThreshold = replacementThreshold
            self.automaticReplacementEnabled = automaticReplacementEnabled
            self.calibratedPrecision = calibratedPrecision
        }
    }

    private struct Entry: Sendable {
        let text: String
        let identity: String
        let frequency: Int
    }

    private struct ScoredCandidate {
        let entry: Entry
        let confidence: Double
    }

    private let entries: [Entry]
    private let knownWords: Set<String>
    private let personalWords: Set<String>
    private let bigramFrequencies: [String: Int]
    private let language: String
    private let configuration: Configuration

    init(wordFrequencies: [String: Int],
         personalWords: Set<String> = [],
         bigramFrequencies: [String: Int] = [:],
         language: String = "en_US",
         configuration: Configuration = .init()) {
        entries = wordFrequencies
            .filter { !$0.key.isEmpty }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            .prefix(2_048)
            .map { Entry(text: $0.key, identity: $0.key.lowercased(), frequency: max(0, $0.value)) }
        knownWords = Set(entries.map(\.identity))
        self.personalWords = Set(personalWords.map { $0.lowercased() })
        self.bigramFrequencies = bigramFrequencies
        self.language = language
        self.configuration = configuration
    }

    func evaluate(committedWord: String,
                  contextBeforeWord: String,
                  contextAfterWord: String,
                  touch: TouchEvidence?,
                  fieldProfile: FieldProfile) -> CorrectionDecision {
        let original = committedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = original.lowercased()
        guard isEligible(original, identity: identity, context: contextBeforeWord,
                         fieldProfile: fieldProfile) else { return .ignore }

        let previous = contextBeforeWord
            .split(whereSeparator: { $0.isWhitespace })
            .last.map { String($0).lowercased() } ?? ""
        let candidates = candidateEntries(for: original, identity: identity)
        guard !candidates.isEmpty else { return .ignore }
        let maximumFrequency = max(1, candidates.map(\.frequency).max() ?? 1)
        let maximumBigram = max(1, candidates.map {
            bigramFrequencies["\(previous)|\($0.identity)"] ?? 0
        }.max() ?? 0)

        let scored: [ScoredCandidate] = candidates.compactMap { entry in
            guard let distance = DamerauLevenshtein.distance(identity, entry.identity, limit: 2) else {
                return nil
            }
            let edit = 1 - Double(distance) / Double(max(identity.count, entry.identity.count, 1))
            let unigram = log1p(Double(entry.frequency)) / log1p(Double(maximumFrequency))
            let bigram = Double(bigramFrequencies["\(previous)|\(entry.identity)"] ?? 0)
                / Double(maximumBigram)
            let features = CorrectionFeatures(
                spatial: spatialUncertainty(from: touch),
                language: min(1, 0.65 * unigram + 0.35 * bigram),
                editSimilarity: min(1, max(0, edit)),
                phonetic: language.lowercased().hasPrefix("en")
                    && DoubleMetaphone.matches(identity, entry.identity) ? 1 : 0,
                personalFrequency: personalWords.contains(entry.identity) ? 1 : 0)
            return ScoredCandidate(entry: entry, confidence: confidence(for: features))
        }
        guard let best = scored.max(by: { left, right in
            if left.confidence != right.confidence { return left.confidence < right.confidence }
            return left.entry.frequency < right.entry.frequency
        }), best.confidence >= configuration.suggestionThreshold else { return .ignore }

        let replacement = preserveLeadingCase(from: original, in: best.entry.text)
        if configuration.automaticReplacementEnabled,
           configuration.calibratedPrecision >= 0.95,
           best.confidence >= configuration.replacementThreshold {
            return .replace(original: original, replacement: replacement, confidence: best.confidence)
        }
        return .suggest(original: original, replacement: replacement, confidence: best.confidence)
    }

    private func isEligible(_ original: String,
                            identity: String,
                            context: String,
                            fieldProfile: FieldProfile) -> Bool {
        guard fieldProfile != .url, fieldProfile != .email,
              original.count >= 2, original.count <= 64,
              !knownWords.contains(identity),
              !personalWords.contains(identity),
              original.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" }),
              !original.contains(where: { $0.isNumber }) else { return false }
        let letters = original.filter(\.isLetter)
        if letters.count >= 2, letters == letters.uppercased() { return false }
        if original.first?.isUppercase == true,
           !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    private func candidateEntries(for original: String, identity: String) -> [Entry] {
        var candidates: [String: Entry] = [:]
        for entry in entries where abs(entry.identity.count - identity.count) <= 2 {
            guard DamerauLevenshtein.distance(identity, entry.identity, limit: 2) != nil else { continue }
            candidates[entry.identity] = entry
            if candidates.count == 64 { break }
        }

#if canImport(UIKit)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: original.utf16.count)
        for guess in checker.guesses(forWordRange: range, in: original, language: language) ?? [] {
            let guessIdentity = guess.lowercased()
            guard candidates.count < 64,
                  candidates[guessIdentity] == nil,
                  DamerauLevenshtein.distance(identity, guessIdentity, limit: 2) != nil else { continue }
            candidates[guessIdentity] = Entry(text: guess, identity: guessIdentity, frequency: 1)
        }
#endif
        return Array(candidates.values)
    }

    private func spatialUncertainty(from touch: TouchEvidence?) -> Double {
        guard let touch else { return 0.5 }
        let selected = touch.neighborLikelihoods[touch.intendedKeyIndex] ?? 1
        return min(1, max(0, 1 - selected))
    }

    private func confidence(for features: CorrectionFeatures) -> Double {
        let logit = -2.4
            + 0.6 * features.spatial
            + 1.1 * features.language
            + 2.8 * features.editSimilarity
            + 0.8 * features.phonetic
            + 0.5 * features.personalFrequency
        return 1 / (1 + exp(-logit))
    }

    private func preserveLeadingCase(from original: String, in replacement: String) -> String {
        guard original.first?.isUppercase == true, let first = replacement.first else { return replacement }
        return first.uppercased() + replacement.dropFirst()
    }
}

enum DamerauLevenshtein {
    static func distance(_ left: String, _ right: String, limit: Int) -> Int? {
        let lhs = Array(left)
        let rhs = Array(right)
        guard abs(lhs.count - rhs.count) <= limit else { return nil }
        if lhs == rhs { return 0 }
        var matrix = Array(
            repeating: Array(repeating: 0, count: rhs.count + 1),
            count: lhs.count + 1)
        for index in 0...lhs.count { matrix[index][0] = index }
        for index in 0...rhs.count { matrix[0][index] = index }

        for i in 1...lhs.count {
            var rowMinimum = Int.max
            for j in 1...rhs.count {
                let substitution = matrix[i - 1][j - 1] + (lhs[i - 1] == rhs[j - 1] ? 0 : 1)
                matrix[i][j] = min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, substitution)
                if i > 1, j > 1,
                   lhs[i - 1] == rhs[j - 2], lhs[i - 2] == rhs[j - 1] {
                    matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1)
                }
                rowMinimum = min(rowMinimum, matrix[i][j])
            }
            if rowMinimum > limit { return nil }
        }
        let result = matrix[lhs.count][rhs.count]
        return result <= limit ? result : nil
    }
}
