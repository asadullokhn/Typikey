import Foundation

enum PredictionSource: String, Codable, Sendable {
    case prefix
    case personal
    case screen
    case learnedNGram
    case seedNGram
    case foundationModel
}

enum FieldProfile: String, Codable, Sendable {
    case conversational
    case search
    case email
    case url
    case generic
}

struct PredictionRequest: Sendable {
    let contextBefore: String
    let partialWord: String
    let sentenceStart: Bool
    let fieldProfile: FieldProfile
    let maximumCandidates: Int
}

struct PredictionCandidate: Equatable, Sendable {
    let text: String
    let score: Double
    let source: PredictionSource

    var identity: String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }
}

struct PredictionResult: Equatable, Sendable {
    let candidates: [PredictionCandidate]
    let generatedAt: ContinuousClock.Instant

    init(candidates: [PredictionCandidate],
         generatedAt: ContinuousClock.Instant,
         maximumCandidates: Int) {
        self.candidates = Array(candidates.prefix(max(0, maximumCandidates)))
        self.generatedAt = generatedAt
    }
}
