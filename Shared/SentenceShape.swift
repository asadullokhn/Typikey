import Foundation

/// What the sentence needs next, and which cells therefore have nothing
/// left to say.
///
/// Type "I want" and five subject-pronoun cells become dead weight —
/// nothing that follows can read "I want he". Those cells are the board's
/// only spare capacity, so this works out when they are spent and what
/// they can carry instead: after "eat", the food page's words; after
/// "watch", the ones from Web. A category's worth of vocabulary reaches
/// home without home gaining a single cell.
///
/// Deliberately narrow. It answers two questions — what is the only thing
/// that can come next, and what certainly cannot — and says `.any` to
/// everything it is not sure about. A board that rearranges itself on a
/// guess is worse than one that never moves, and the evidence for stable
/// positions is the strongest in this project (Thistle et al. 2018
/// measured 3.3s per selection against fixed targets versus 6.0s against
/// moving ones). So it changes cells only where the grammar leaves no
/// doubt.
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
        /// A noun is what comes next: after an article or a determiner,
        /// and after a verb that takes an object. "write a ___" and
        /// "eat ___" can be almost nothing else.
        case noun
        /// No confident reading. The board stays exactly as it is.
        case any
    }

    /// After a determiner, a noun is all that can follow. This is where
    /// most letter-by-letter typing was going: measuring six real
    /// sentences, every single noun after "a" or "the" — story, monster,
    /// park, video — had to be spelled out, even the ones already sitting
    /// on a board two taps away.
    static let nounCallers: Set<String> = [
        "a", "an", "the", "my", "your", "his", "her", "our", "their",
        "this", "that", "some", "any", "every",
    ]

    /// Verbs that take an object, so what follows is a thing rather than
    /// anything at all. Listed rather than inferred: English transitivity
    /// is a property of each verb, no suffix reveals it, and getting it
    /// wrong here means the board changes when it should have held still.
    ///
    /// Only verbs whose object is a bare noun. "look" and "wait" are
    /// absent because their objects arrive through a preposition — "look
    /// at the picture" — and "for" and "at" must stay reachable.
    private static let transitiveVerbs: Set<String> = [
        "want", "like", "have", "eat", "drink", "watch", "read", "write",
        "draw", "play", "make", "open", "close", "give", "get", "need",
        "search", "share", "download", "paint", "help", "see", "buy",
        "wants", "likes", "has", "eats", "drinks", "watches", "reads",
        "writes", "draws", "plays", "makes", "opens", "closes", "gives",
        "gets", "needs", "sees", "buys",
        "wanted", "liked", "had", "ate", "drank", "watched", "read",
        "wrote", "drew", "played", "made", "opened", "closed", "gave",
        "got", "needed", "saw", "bought", "helped", "painted",
    ]

    /// Subjects. Object and possessive pronouns are deliberately absent:
    /// "can you help me" needs `me`, so `me` and `my` are never spent.
    static let subjectPronouns: Set<String> =
        ["i", "you", "he", "she", "it", "we", "they"]

    /// The pronouns that can ONLY be subjects. `you` and `it` are the two
    /// English pronouns spelled the same in both roles, so "I want you"
    /// and "I like it" are ordinary sentences and those two cells are
    /// never spare after a verb.
    private static let subjectOnlyPronouns: Set<String> =
        ["i", "he", "she", "we", "they"]

    private static let questionWords: Set<String> =
        ["what", "where", "when", "who", "why", "how"]

    static func expected(after context: String) -> Slot {
        let words = Grammar.words(in: Grammar.currentSentence(context))
        guard let last = words.last else { return .any }

        if nounCallers.contains(last) { return .noun }

        // An auxiliary is followed by a verb ONLY once the clause has a
        // subject. Start a question with one — "Can ___" — and what comes
        // next is the subject, so the pronouns are the most useful keys on
        // the board, not the most useless. Spending them there took the
        // words the sentence needed and offered ones it could not use.
        if Grammar.verbGovernors.contains(last) {
            return words.contains(where: subjectPronouns.contains) ? .verb : .any
        }
        // A verb with an object waiting is the other half of the win, and
        // the larger one: "I want ___" and "we eat ___" are where the
        // sentence reaches for a word that lives three taps away on a
        // category page. `to` and the other function words keep their
        // cells, so "I want to go" is still one tap a word.
        if transitiveVerbs.contains(last) { return .noun }
        // A bare subject at the head of a sentence wants a verb — "I ___",
        // "Can you ___" — but only that early. Deeper in, "with you ___"
        // could go anywhere.
        if subjectPronouns.contains(last), words.count <= 2 { return .verb }
        return .any
    }

    /// Whether a word on the board cannot possibly be what comes next, and
    /// so can lend its cell to a word that can.
    ///
    /// The test is grammatical impossibility, not unlikelihood. A cell is
    /// only taken when there is no English sentence in which that word
    /// follows this context — anything merely improbable keeps its place,
    /// because a key that vanishes when he wanted it costs far more than a
    /// key he had to go and find.
    static func cannotFollow(_ word: String, when slot: Slot) -> Bool {
        let word = word.lowercased()
        switch slot {
        case .verb:
            // Only a verb fits, so every closed-class word that is not one
            // gives up its cell. `not` is excluded by being none of these:
            // "can you not go" is a sentence he needs.
            return subjectPronouns.contains(word)
                || nounCallers.contains(word)
                || questionWords.contains(word)
        case .noun:
            return subjectOnlyPronouns.contains(word)
                || questionWords.contains(word)
        case .any:
            return false
        }
    }
}
