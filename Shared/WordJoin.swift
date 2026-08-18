import Foundation

/// Words that fuse to their neighbours instead of being spaced off them.
///
/// A web address is typed in pieces — `www.` then the name then `.com` —
/// and has to come out as one token. Ordinary spacing would give
/// "Www. google .com".
enum WordJoin {
    private static let joiners: Set<Character> = [".", "/", "-", "@", ":", "_"]

    /// "www." takes whatever follows straight after it.
    static func trails(_ word: String) -> Bool {
        guard word.count > 1, let last = word.last else { return false }
        return joiners.contains(last)
    }

    /// ".com" attaches to whatever precedes it.
    static func leads(_ word: String) -> Bool {
        guard word.count > 1, let first = word.first else { return false }
        return joiners.contains(first)
    }

    /// True when the text stops mid-address, so the next word must not be
    /// spaced off it. Sentence-ending punctuation always leaves a space
    /// behind it, which is what keeps "Hello." from matching here.
    static func continues(_ context: String) -> Bool {
        guard let last = context.last else { return false }
        return joiners.contains(last)
    }

    static func isJoiner(_ word: String) -> Bool { trails(word) || leads(word) }
}
