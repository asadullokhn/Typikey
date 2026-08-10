import Foundation

/// Frequency stores, kept bounded.
///
/// Everything here counts words the user has met — typed letter by letter,
/// or read off the screen — and every one of them grows on its own. A
/// store that only grows is written back in full on every keystroke that
/// touches it, inside a process with a 60-80MB ceiling, and the words that
/// make it large are precisely the ones that never mattered: typos,
/// fragments, a name seen once.
///
/// So each store has a ceiling, and when it is reached the least-seen
/// words go first. Losing a word seen twice years ago costs nothing; the
/// ones that matter are the ones that keep coming back.
enum WordCounts {
    /// Ceiling shared by every frequency store. Chosen to be far above a
    /// realistic working vocabulary, so trimming only ever discards the
    /// long tail.
    static let limit = 400

    static func trimmed(_ counts: [String: Int], to limit: Int = limit) -> [String: Int] {
        guard counts.count > limit else { return counts }
        return Dictionary(
            uniqueKeysWithValues: counts.sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) })
    }
}
