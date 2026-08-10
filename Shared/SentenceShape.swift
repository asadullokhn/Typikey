import Foundation

/// What the sentence needs next.
///
/// Type "can you" and seven subject-pronoun cells become dead weight —
/// nothing that follows can read "can you I". Those cells are the board's
/// only spare capacity, so this works out when they are spent and they can
/// carry something useful instead.
///
/// Deliberately narrow. It answers one question — is a verb the only thing
/// that can come next? — and says `.any` to everything else. A board that
/// rearranges itself on a guess is worse than one that never moves, and
/// the evidence for stable positions is the strongest in this project
/// (Thistle et al. 2018 measured 3.3s per selection against fixed targets
/// versus 6.0s against moving ones). So it changes cells only where the
/// grammar leaves no doubt.
///
/// Derived from the text, never stored. That is what makes it reversible
/// for free: delete a word and the shape is recomputed from what is left,
/// clear everything and the board is back where it started. There is no
/// state to unwind because there is no state.
enum SentenceShape {

    enum Slot {
        /// A verb is the only thing that fits: after a subject, a modal,
        /// or an auxiliary.
        case verb
        /// No confident reading. The board stays exactly as it is.
        case any
    }

    /// Subjects. Object and possessive pronouns are deliberately absent:
    /// "can you help me" needs `me`, so `me` and `my` are never spent.
    static let subjectPronouns: Set<String> =
        ["i", "you", "he", "she", "it", "we", "they"]

    /// After these, English allows a verb and very little else.
    private static let verbCallers: Set<String> = [
        "can", "will", "would", "could", "should", "must", "may", "might", "shall",
        "do", "does", "did", "don't", "doesn't", "didn't", "won't", "can't",
        "am", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "to", "please", "let",
    ]

    static func expected(after context: String) -> Slot {
        let sentence = currentSentence(context)
        let words = sentence
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
        guard let last = words.last else { return .any }
        if verbCallers.contains(last) { return .verb }
        // A bare subject at the head of a sentence still wants a verb —
        // "I ___" — but only when it is the whole sentence so far. Deeper
        // in, "with you ___" could go anywhere.
        if subjectPronouns.contains(last), words.count <= 2 { return .verb }
        return .any
    }

    /// The sentence in progress, not everything in the field.
    private static func currentSentence(_ context: String) -> String {
        guard let end = context.lastIndex(where: { ".!?\n".contains($0) }) else { return context }
        return String(context[context.index(after: end)...])
    }
}
