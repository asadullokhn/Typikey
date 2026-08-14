import Foundation

enum CompletionSanitizer {
    private static let trailingPunctuation = CharacterSet(charactersIn: ".!?,;:…")

    static func words(from candidates: [String], limit: Int = 5) -> [String]? {
        guard limit > 0 else { return nil }
        for candidate in candidates {
            let words = candidate
                .replacingOccurrences(of: "\n", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .map { $0.trimmingCharacters(in: trailingPunctuation) }
                .filter { $0.rangeOfCharacter(from: .alphanumerics) != nil }
                .prefix(limit)
            if !words.isEmpty { return Array(words) }
        }
        return nil
    }
}
