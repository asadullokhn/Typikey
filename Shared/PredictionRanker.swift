import Foundation

struct PredictionRanker: Sendable {
    static let sourceWeights: [PredictionSource: Double] = [
        .personal: 1.30,
        .prefix: 1.15,
        .learnedNGram: 1.10,
        .screen: 1.05,
        .seedNGram: 1.00,
        .foundationModel: 0.90,
    ]

    func rank(_ candidates: [PredictionCandidate], limit: Int) -> [PredictionCandidate] {
        guard limit > 0 else { return [] }
        let valid = candidates.enumerated().filter {
            $0.element.score.isFinite && $0.element.score > 0 && !$0.element.identity.isEmpty
        }
        let maxima = Dictionary(grouping: valid, by: { $0.element.source })
            .mapValues { entries in entries.map(\.element.score).max() ?? 1 }

        struct Entry {
            let candidate: PredictionCandidate
            let order: Int
        }

        var bestByIdentity: [String: Entry] = [:]
        for entry in valid {
            let candidate = entry.element
            let normalized = candidate.score / (maxima[candidate.source] ?? 1)
            let weighted = normalized * (Self.sourceWeights[candidate.source] ?? 1)
            let scored = PredictionCandidate(
                text: candidate.text,
                score: weighted,
                source: candidate.source)
            if let existing = bestByIdentity[candidate.identity],
               existing.candidate.score >= scored.score {
                continue
            }
            bestByIdentity[candidate.identity] = Entry(candidate: scored, order: entry.offset)
        }

        return bestByIdentity.values
            .sorted {
                if $0.candidate.score != $1.candidate.score {
                    return $0.candidate.score > $1.candidate.score
                }
                return $0.order < $1.order
            }
            .prefix(limit)
            .map(\.candidate)
    }
}
