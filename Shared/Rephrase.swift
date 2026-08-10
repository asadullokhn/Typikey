import Foundation

/// Turns what he had time to type into what he meant to say.
///
/// AAC output is telegraphic because every word costs up to thirty
/// seconds: "I play you" is three taps and perfectly clear to anyone who
/// knows him, and it is also not a sentence. The words that go missing
/// are always the same ones — the auxiliary, the preposition, the
/// inversion that makes it a question — because they carry grammar rather
/// than meaning, and meaning is what he spends his taps on.
///
/// So the keyboard supplies them. Press `?` after "I play you" and the
/// suggestion bar offers "Do you want to play with me?" — the sentence he
/// would have written with unlimited time, from the sentence he wrote
/// with none.
///
/// Two rules keep this honest:
///
/// **It never rewrites anything on its own.** Rephrasings appear in the
/// suggestion bar, which is where every prediction in this keyboard lives
/// (invariant 6) and where nothing happens unless he taps it. Accepting
/// costs one tap; ignoring costs none; what he typed stays exactly as he
/// typed it either way. A feature that silently replaced a sentence that
/// took four minutes to write would be the worst thing in the app.
///
/// **His literal sentence is always among the options.** Every rephrasing
/// is a guess about intent, and the guess is sometimes wrong. Repairing
/// what he actually wrote — capitalised, agreeing, with its question mark
/// — is always offered, so choosing the machine's reading of his sentence
/// is a decision he makes rather than one made for him.
///
/// Entirely local, like everything else here: a table of English, not a
/// model, and no network call ever (invariant 5).
enum Rephrase {

    /// Ways of saying what the sentence in progress seems to mean, best
    /// guess first, capped at what the suggestion bar can show.
    static func questions(from context: String) -> [String] {
        let sentence = Grammar.currentSentence(context)
        let words = Grammar.words(in: sentence)
        guard words.count >= 2 else { return [] }

        // What he wrote, repaired but not reinterpreted, always last and
        // always present: every option above it is a guess about what he
        // meant, and this one is the only thing he actually said.
        var seen = Set<String>()
        return (candidates(for: words) + [finished(words)])
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Reading the sentence

    private static func candidates(for words: [String]) -> [String] {
        // Already inverted — "can you write a story" — so it is a question
        // already and needs no rebuilding, only its mark.
        if let first = words.first, auxiliaries.contains(first) { return [] }

        if questionWords.contains(words[0]) { return fromQuestionWord(words) }
        if let subject = subjectIndex(words) { return fromStatement(words, subjectAt: subject) }
        // No subject at all: an imperative, which in a message to another
        // person is nearly always a request. "help me" -> "Can you help
        // me?"
        if let verb = verbIndex(words, from: 0) {
            return [finished(["can", "you"] + base(words, verbAt: verb))]
        }
        return []
    }

    /// "what time dinner", "where Mum" — a question word and no verb to
    /// carry it.
    private static func fromQuestionWord(_ words: [String]) -> [String] {
        let rest = Array(words.dropFirst())
        guard !rest.isEmpty else { return [] }

        if let verb = verbIndex(rest, from: 0) {
            // "what you want" -> "What do you want?". The auxiliary takes
            // the tense so the verb stays base, exactly as it does on the
            // board.
            guard verb > 0 else { return [] }
            let subject = rest[verb - 1]
            // "what you doing" is asking about something in progress, and
            // do-support flattens it to "what do you do" — a different
            // question. The auxiliary that matches the aspect he wrote is
            // the copula.
            if rest[verb].hasSuffix("ing"), Grammar.baseForm(of: rest[verb]) != nil {
                let auxiliary = Grammar.inflect("be", as: .base, subject: subject)
                return [finished([words[0], auxiliary] + rest)]
            }
            // "what time we go" -> "What time do we go?": the auxiliary
            // belongs in front of the subject, and everything between the
            // question word and the subject stays where he put it.
            let support = Grammar.thirdPerson(subject) ? "does" : "do"
            var built = Array(rest[..<(verb - 1)]) + [support] + Array(rest[(verb - 1)...])
            built[built.count - rest.count + verb] = Grammar.baseForm(of: rest[verb]) ?? rest[verb]
            return [finished([words[0]] + built)]
        }
        // No verb: the copula is what went missing. It belongs in front of
        // the whole noun phrase being asked about — "where IS MY Dad", not
        // "where my is Dad" — so the insertion point is the phrase's
        // determiner rather than its noun.
        // "how long IS the ride": the thing being asked about is whatever
        // the last determiner introduces, even when the noun after it is a
        // word the keyboard has never seen.
        guard let noun = rest.lastIndex(where: {
            nounWords.contains($0) || demonstratives.contains($0) || SentenceShape.nounCallers.contains($0)
        }) else { return [] }
        // Agree with the noun, not with its article: "the" tells you
        // nothing about number, and asking it gave "How long be the ride?".
        // An unknown noun after a determiner is singular by default, which
        // is right far more often than it is wrong.
        let agreesWith = SentenceShape.nounCallers.contains(rest[noun])
            ? (noun + 1 < rest.count && plurals.contains(rest[noun + 1]) ? "they" : "it")
            : rest[noun]
        let copula = Grammar.inflect("be", as: .base, subject: agreesWith)
        var built = rest
        built.insert(copula, at: subjectStart(rest, subjectAt: noun))
        return [finished([words[0]] + built)]
    }

    /// The common case, and the one worth the most: a subject, a verb, and
    /// whatever he had taps left for.
    private static func fromStatement(_ words: [String], subjectAt subject: Int) -> [String] {
        guard let verb = verbIndex(words, from: subject + 1) else {
            // "I hungry", "you okay", "I not happy" — subject, then what he
            // is, and no verb at all. English is one of the few languages
            // that insists on a copula here, which is exactly why it is
            // the word an AAC user drops first.
            let rest = Array(words[(subject + 1)...])
            // Only in front of something a copula can actually precede. A
            // word this keyboard does not recognise is far more likely to
            // be a verb it has not been taught than an adjective, and
            // guessing gave "Are you finish the homework?".
            guard let next = rest.first(where: { $0 != "not" }),
                  descriptorWords.contains(next) || nounWords.contains(next)
                    || SentenceShape.nounCallers.contains(next)
            else { return [] }
            let copula = Grammar.inflect("be", as: .base, subject: words[subject])
            return [finished([copula] + Array(words[subjectStart(words, subjectAt: subject)...subject]) + rest)]
        }
        let verbWord = Grammar.baseForm(of: words[verb]) ?? words[verb]
        let rest = Array(words[(verb + 1)...])
        let speaking = person(words[subject])
        // The subject he wrote, not the person it belongs to: "we play
        // game" is a question about the two of them, and rebuilding it
        // around "I" answered a question nobody asked.
        let subjectWord = words[subject]

        // The copula inverts rather than taking do-support: English asks
        // "Is the dinner ready?", never "Does the dinner be ready?". It is
        // the one verb that still moves to the front of its own question,
        // and it is also the most common verb in the language.
        if Grammar.baseForm(of: words[verb]) == "be" {
            let start = subjectStart(words, subjectAt: subject)
            let inverted = Grammar.inflect("be", as: .base, subject: words[subject])
            return [finished([inverted] + Array(words[start...subject]) + rest)]
        }

        // "I play you" — he is the subject and the person he is writing to
        // is the object, which is not a statement about either of them. It
        // is an invitation, and the only English that says so puts the
        // other person in front: "Do you want to play with me?"
        if speaking == .first, rest.first.map({ person($0) == .second }) == true {
            let tail = Array(rest.dropFirst())
            // "I want you help me" means "I want you TO help me", so what
            // he is asking for is the helping. Rebuilding it around `want`
            // gave "Do you want to want me help me?".
            if wantVerbs.contains(verbWord),
               let next = tail.first(where: { $0 != "to" }),
               let inner = Grammar.baseForm(of: next) {
                let after = Array(tail.drop { $0 == "to" || $0 == next })
                return [finished(["can", "you", inner] + destination(after, after: inner))]
            }
            let joiner = companionVerbs.contains(verbWord) ? ["with", "me"] : ["me"]
            return [finished(["do", "you", "want", "to", verbWord] + joiner + destination(tail, after: verbWord))]
        }

        // "you help me" — the same sentence from the other side, which is
        // a request rather than an invitation.
        if speaking == .second {
            let tail = destination(rest, after: verbWord)
            return [finished(["can", "you", verbWord] + tail),
                    finished(["do", "you", "want", "to", verbWord] + tail)]
        }

        if speaking == .first {
            // "I want juice" asked as a question is asking for juice.
            // `have` rather than `want`, because "Can I want juice?" is
            // not a request for anything.
            if wantVerbs.contains(verbWord), let first = rest.first {
                // "I want to eat rice" wants the eating, not the having.
                // The request is about the verb after "to", so that is the
                // verb the question asks permission for.
                if first == "to", rest.count >= 2, let inner = Grammar.baseForm(of: rest[1]) {
                    let tail = Array(rest.dropFirst(2))
                    return [finished(["can", subjectWord, inner] + destination(tail, after: inner))]
                }
                if first != "to" {
                    return [finished(["can", subjectWord, "have"] + rest),
                            finished(["can", subjectWord, verbWord] + rest)]
                }
            }
            // Asking permission only makes sense for something you do.
            // "Can I like it?" is not a request for anything, so an
            // opinion is left as the opinion he wrote.
            guard !opinionVerbs.contains(verbWord) else { return [] }
            return [finished(["can", subjectWord, verbWord] + destination(rest, after: verbWord))]
        }

        // A third party: "Mum come home" -> "Is Mum coming home?" is a
        // guess too far, so this asks the plain do-supported question.
        //
        // The subject is everything from the first determiner in front of
        // it, not the bare noun: "my head hurts" asked as "Does head
        // hurt?" is about somebody's head, and the somebody was the point.
        let support = Grammar.thirdPerson(words[subject]) ? "does" : "do"
        return [finished([support] + Array(words[subjectStart(words, subjectAt: subject)...subject])
                         + [verbWord] + rest)]
    }

    /// Where the subject really starts: at its determiner, not at its
    /// noun. "my head hurts" asked as "Does head hurt?" is about somebody
    /// else's head, and the somebody was the point.
    private static func subjectStart(_ words: [String], subjectAt subject: Int) -> Int {
        words[..<subject].lastIndex { !SentenceShape.nounCallers.contains($0) }
            .map { $0 + 1 } ?? (subject > 0 ? 0 : subject)
    }

    // MARK: - Words

    private enum Person { case first, second, other }

    private static func person(_ word: String) -> Person {
        if ["i", "me", "my", "mine", "we", "us", "our"].contains(word) { return .first }
        if ["you", "your", "yours"].contains(word) { return .second }
        return .other
    }

    /// Words that can start a clause. Object and possessive forms are
    /// excluded deliberately: "help me" has no subject, and reading `me`
    /// as one turned a request into the statement "Help me?" instead of
    /// "Can you help me?".
    private static func isSubjectForm(_ word: String) -> Bool {
        ["i", "you", "he", "she", "it", "we", "they"].contains(word) || nounWords.contains(word)
    }

    /// Plural markers a bare noun cannot show. Only the ones the board can
    /// write, because a rule that guessed at plurals would get "the fish
    /// are" and "the news are" wrong in the same breath.
    private static let plurals: Set<String> = ["they", "these", "those", "people", "days", "ideas"]

    /// "who that", "what this" — pronouns standing in for a noun, and the
    /// copula has to agree with something.
    private static let demonstratives: Set<String> = ["this", "that", "these", "those", "it"]

    private static let questionWords: Set<String> =
        ["what", "where", "when", "who", "why", "how"]

    private static let auxiliaries: Set<String> = [
        "can", "could", "will", "would", "shall", "should", "may", "might",
        "must", "do", "does", "did", "is", "are", "am", "was", "were",
        "have", "has", "had",
    ]

    /// Verbs whose human companion arrives through "with": you play WITH
    /// someone, but you help someone. Getting this wrong is the difference
    /// between "play with me" and "play me".
    private static let companionVerbs: Set<String> = [
        "play", "go", "come", "eat", "drink", "sit", "talk", "stay",
        "walk", "read", "draw", "write", "watch", "work",
    ]

    /// States rather than acts. You do not ask permission to like
    /// something, so these keep the sentence he wrote instead of being
    /// bent into a request.
    private static let opinionVerbs: Set<String> = [
        "like", "love", "know", "understand", "feel", "think", "hurt", "see",
    ]

    /// Verbs where wanting a thing and asking for it are the same act.
    /// `like` is not among them — "I like it" is an opinion, and "Can I
    /// have it?" is not what it means.
    private static let wantVerbs: Set<String> = ["want", "need"]

    /// Who the sentence is about.
    ///
    /// A pronoun wins over a noun wherever it appears, because a name at
    /// the front of a message is almost always the person being addressed
    /// rather than the subject: "Mum I hungry" is about him, and reading
    /// `Mum` as the subject produced "Is Mum I hungry?".
    private static func subjectIndex(_ words: [String]) -> Int? {
        words.firstIndex { ["i", "you", "he", "she", "it", "we", "they"].contains($0) }
            ?? words.firstIndex(where: isSubjectForm)
            ?? words.firstIndex { demonstratives.contains($0) }
    }

    /// The first word from `start` that the board could have made as a
    /// verb. Determiners and prepositions are skipped by not being verbs.
    private static func verbIndex(_ words: [String], from start: Int) -> Int? {
        guard start < words.count else { return nil }
        return (start..<words.count).first { Grammar.baseForm(of: words[$0]) != nil }
    }

    /// Restores the preposition a motion verb dropped. "I go park" is
    /// three taps and means "go to the park"; nothing else it could mean
    /// is English, which is why this is the one preposition worth
    /// inserting and the rest are left alone.
    private static func destination(_ rest: [String], after verb: String) -> [String] {
        guard ["go", "come", "walk", "run"].contains(verb),
              let first = rest.first, placeWords.contains(first),
              !["to", "at", "in", "from"].contains(first)
        else { return rest }
        // "home" and "outside" are adverbs here: you go home, never to the
        // home. School, work and bed take the preposition but not the
        // article — "go to school" — which is an English irregularity with
        // no rule behind it, so it is listed.
        if ["home", "outside", "here", "there"].contains(first) { return rest }
        if ["school", "work", "bed", "hospital", "church"].contains(first) { return ["to"] + rest }
        return ["to", "the"] + rest
    }

    /// The sentence from the verb onward, with the verb in its dictionary
    /// form — what an auxiliary in front of it requires.
    private static func base(_ words: [String], verbAt verb: Int) -> [String] {
        var built = Array(words[verb...])
        built[0] = Grammar.baseForm(of: words[verb]) ?? words[verb]
        if verb > 0 { built = Array(words[..<verb]) + built }
        return built
    }

    // MARK: - Writing it out

    /// A question, spelled the way a person would write one.
    private static func finished(_ words: [String]) -> String {
        guard !words.isEmpty else { return "" }
        var written = words
            .map { $0 == "i" ? "I" : (canonicalSpelling[$0] ?? $0) }
            .joined(separator: " ")
        written = written.prefix(1).uppercased() + written.dropFirst()
        return written + "?"
    }
}
