import Foundation

/// What the board shows, worked out from the sentence.
///
/// This is the keyboard's answer to the only question the project turns
/// on: what does saying something cost? Every word is either one tap
/// because it is on the board, three taps because it is on a category
/// page, or a letter at a time because it is nowhere. Which of those a
/// word gets is decided here.
///
/// It lives apart from the keyboard, and holds no reference to one, so
/// the cost of a sentence can be measured by calling a function instead
/// of booting a simulator, installing an extension and driving it through
/// the UI test runner. `Tools/tapcost` runs the whole corpus in about a
/// second, which is what makes it affordable to ask "would dropping this
/// word hurt?" before writing the change rather than after.
struct BoardPlan {

    /// Everything the board knows about this particular user. All of it
    /// optional: a fresh install passes an empty one and the board still
    /// works, which is also what makes cold-start behaviour measurable.
    struct Learning {
        var usage: [String: Int]
        var bigrams: [String: Int]
        var screen: [String: Int]
        var mine: [String]

        init(usage: [String: Int] = [:],
             bigrams: [String: Int] = [:],
             screen: [String: Int] = [:],
             mine: [String] = []) {
            self.usage = usage
            self.bigrams = bigrams
            self.screen = screen
            self.mine = mine
        }
    }

    var learning = Learning()
    var followsSentence = true
    var smartGrammar = true

    /// What a model precomputed in the app, if anybody turned that on.
    ///
    /// Weighted low on purpose. The first table ever measured here made the
    /// corpus 50 taps worse, and only because it was loaded into the learned
    /// bigrams — which score ten times anything else — did that damage reach
    /// the board at all. A model's guess is evidence, not the verdict, so it
    /// is added beside the seeds rather than on top of everything.
    var assist: PredictionTable?
    var assistWeight = 2

    private func assistScores(after previous: String) -> [(String, Int)] {
        guard let words = assist?.continuations[previous.lowercased()] else { return [] }
        return words.enumerated().map { ($1.lowercased(), max(1, assistWeight * (5 - $0)) ) }
    }

    /// What a cell reads right now.
    ///
    /// Verb keys follow the sentence: after "I am", `go` reads `going`.
    /// The cell does not move — this is the same relabel-in-place
    /// mechanism the language switch used to use (invariant 1).
    ///
    /// Returns the base form alongside, because a relabelled key has to
    /// be able to say what it started as: the keyboard needs it to record
    /// usage against the real word rather than against `went`.
    func label(for word: VocabWord, after context: String) -> (text: String, base: String) {
        let base = word.text
        guard smartGrammar else { return (base, base) }
        switch word.wordClass {
        case .verb:
            return (Grammar.inflect(base,
                                    as: Grammar.verbForm(after: context),
                                    subject: Grammar.subject(before: context)), base)
        case .noun:
            // "how many day" is not something anyone writes, and `days`
            // was on no board at all — the plural of a word we already
            // have is not new vocabulary, it is the same key reading
            // correctly. Only where the grammar leaves no doubt: after a
            // number or a quantifier, and never for the nouns English
            // does not count.
            guard Grammar.expectsPlural(after: context),
                  let plural = Grammar.plural(of: base) else { return (base, base) }
            return (plural, base)
        default:
            return (base, base)
        }
    }

    // MARK: - Home

    /// The home board, named word by word.
    ///
    /// Four rows leave 33 word cells and Core is 54 words, so home cannot
    /// simply be "all of Core" — it has to be chosen. What earns a cell
    /// here is what a sentence cannot be built without: every pronoun, the
    /// auxiliaries, the few verbs that combine with everything, and the
    /// closed classes. "I am waiting" is a dead end without `for`, which
    /// is why `for` is here and `where` is not.
    ///
    /// Every word named here is defined once, in a category. This list
    /// only decides what is one tap away instead of three.
    ///
    /// `a` and `the` were off this board for eleven builds, on the
    /// argument that "I want the book" degrading to "I want book" is
    /// telegraphic but understood. Measuring it ended the argument: across
    /// the sentence corpus they were the single largest block of words
    /// being spelled letter by letter. An article is three letters and two
    /// level changes — five taps, up to two and a half minutes — to say
    /// something the reader would have inferred. They are back.
    ///
    /// The board is full, so two words paid for them. `tomorrow` went
    /// because `will` is already here and does the same job — the future
    /// has an auxiliary, which is why English needs no future tense
    /// ending; the past has none, which is why `yesterday` stays and is
    /// the only thing that can put the verb keys in the past. `on` went
    /// because it is the least load-bearing of five prepositions, and
    /// unlike the others it is rarely the word a sentence dies without.
    static let homeSelection = [
        "I", "you", "he", "she", "it", "we", "they",
        "be", "do", "have", "can", "will",
        "want", "like", "go", "help", "stop",
        "not", "more",
        "to", "for", "with", "in",
        "and", "my", "a", "the", "yesterday",
        "what", "yes", "no", ".", "?",
        // Appended, never inserted (invariant 1). Hide keyboard moving to
        // the pinned column freed a grid cell, and this is what the
        // corpus says to spend it on: `that` is the cheapest 30 taps in
        // the list, ahead of `now` (24) and `me` (19), because "that is
        // funny" and "I like that" are half of what anyone says.
        //
        // One word, not two. When iOS requires the globe it takes the
        // pinned slot and Hide keyboard falls back into the grid, leaving
        // 36 cells rather than 37 — so a 35th word would appear on most
        // iPads and silently vanish on any device with a second keyboard
        // installed. That failure has cost this project a build before.
        "that",
    ]

    /// Looked up across the whole vocabulary rather than in one category:
    /// home draws on Core and Little words both, and which board a word is
    /// filed under is not home's business.
    static let homeWords: [VocabWord] = {
        let words = homeSelection.compactMap { vocabIndex[$0] }
        // A name that stops matching a word would simply vanish from the
        // board — silently, with no crash and no gap, because the packer
        // closes up behind it. That is exactly the class of bug that cost
        // us the `be` key for a whole build.
        assert(words.count == homeSelection.count,
               "homeSelection names a word that is in no category")
        return words
    }()

    // MARK: - Following the sentence

    /// Re-offers the cells the sentence has no use for.
    ///
    /// After "can you", nothing can read "can you I", so the subject
    /// pronouns are spare. After "I want", nothing can read "I want he",
    /// so the subject-only pronouns are spare and the board fills them
    /// with what people actually want — from the food, place and thing
    /// pages, ranked by what tends to follow the verb he just tapped.
    /// This is how a category's worth of words reaches home without home
    /// gaining a single cell.
    ///
    /// A swapped cell arrives in its own class colour, orange where yellow
    /// was, so it announces itself without anything being added to the
    /// board. Gilbert's rule: let it configure itself, but visibly.
    ///
    /// Nothing is stored. The shape is recomputed from the text on every
    /// rebuild, which is what makes delete-word and clear-all rewind it
    /// for free — there is no state to unwind, so going back a word puts
    /// the original cells back exactly where they were.
    func reshaped(_ words: [VocabWord], after context: String) -> [VocabWord] {
        guard followsSentence else { return words }
        let slot = SentenceShape.expected(after: context)
        guard slot != .any else { return words }

        var taken = Set(words.map { $0.text.lowercased() })
        var pool = candidates(for: slot, after: context)
            .filter { !taken.contains($0.text.lowercased()) }
        guard !pool.isEmpty else { return words }

        return words.map { word in
            guard SentenceShape.cannotFollow(word.text, when: slot), !pool.isEmpty
            else { return word }
            let replacement = pool.removeFirst()
            taken.insert(replacement.text.lowercased())
            return replacement
        }
    }

    /// What to offer in a spare cell. Read off the boards rather than kept
    /// as a second list, so a word added to any category is a word
    /// available here.
    ///
    /// His own words come first among the nouns: after "my ___" the
    /// likeliest word in the world is a name he added himself, and those
    /// are the words no dictionary or category page will ever hold.
    func candidates(for slot: SentenceShape.Slot, after context: String) -> [VocabWord] {
        let wanted: WordClass = slot == .verb ? .verb : .noun
        var seen = Set<String>()
        let fromBoards = vocabulary
            .flatMap(\.words)
            .filter { $0.wordClass == wanted && seen.insert($0.text.lowercased()).inserted }
            .sorted { (learning.usage[$0.text] ?? 0) > (learning.usage[$1.text] ?? 0) }
        let pool: [VocabWord]
        if wanted == .noun {
            let mine = learning.mine
                .filter { seen.insert($0.lowercased()).inserted }
                .map { VocabWord($0, .social) }
            pool = mine + fromBoards
        } else {
            pool = fromBoards
        }

        // Ranked by the same evidence the suggestion bar uses, not by raw
        // usage. Usage is all zeros on a fresh install, and measuring six
        // real sentences showed what that produces: seven spare cells
        // offering time, Mum, Dad, brother, sister, friend, teacher, while
        // the words those sentences actually needed — story, monster,
        // video, park — sat 24th to 43rd and never appeared at all.
        //
        // The anchor is the last word that is not a determiner, because
        // "watch a ___" is answered by what follows "watch", not by what
        // follows "a".
        let scores = bigramScores(after: Self.anchorWord(in: context))
        guard !scores.isEmpty else { return pool }
        return pool.sorted { (scores[$0.text.lowercased()] ?? 0) > (scores[$1.text.lowercased()] ?? 0) }
    }

    /// The last word carrying meaning: determiners are skipped, since they
    /// predict nothing on their own.
    static func anchorWord(in context: String) -> String {
        let words = Grammar.words(in: Grammar.currentSentence(context))
        return words.reversed().first { !SentenceShape.nounCallers.contains($0) } ?? ""
    }

    /// The three words offered in the suggestion bar. Predictions live
    /// there and nowhere else — the grid never reorders itself to make
    /// room for a guess (invariant 6).
    ///
    /// Here rather than in the keyboard so the bar counts in a measured
    /// sentence: a word reachable from the bar costs one tap from any
    /// level, which for a word buried three taps deep in a category is
    /// most of what this keyboard is for.
    func predictions(after context: String) -> [String] {
        let sentence = Grammar.currentSentence(context)
        let previous = Grammar.words(in: sentence).last ?? ""

        // An inverted question puts the auxiliary before the subject, so
        // at the moment he needs it the board cannot know which one it is
        // — "when ARE you coming" and "how long IS the ride" differ only
        // by a subject that has not been typed. The grid must not guess;
        // one key cannot read both. The bar can show them side by side,
        // which is what it is for (invariant 6), and either is one tap.
        if let inverted = invertedAuxiliaries(after: sentence) { return inverted }
        var scores: [String: Int] = [:]

        let prefix = "\(previous)|"
        for (key, count) in learning.bigrams where key.hasPrefix(prefix) {
            scores[String(key.dropFirst(prefix.count)), default: 0] += count * 10
        }
        for (i, word) in (seedBigrams[previous] ?? []).enumerated() {
            scores[word, default: 0] += 3 - i
        }
        for (word, score) in assistScores(after: previous) {
            scores[word, default: 0] += score
        }
        // Screen context: words the user is looking at right now are
        // likely in the reply. Weighted above the generic seeds but below
        // any real learned bigram, so personal learning always wins.
        for (word, count) in learning.screen.sorted(by: { $0.value > $1.value }).prefix(15) {
            scores[word, default: 0] += min(count, 4)
        }
        // The board already knows what class of word comes next, and the
        // bar was ignoring it — offering "want, like, need" in a place
        // only a noun can go. Same evidence, filtered by the same reading
        // of the sentence the grid uses, so the two never contradict.
        let slot = SentenceShape.expected(after: context)
        if slot != .any {
            let fits = Set(candidates(for: slot, after: context).map { $0.text.lowercased() })
            let filtered = scores.filter { fits.contains($0.key.lowercased()) }
            if !filtered.isEmpty { scores = filtered }
        }
        return scores.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(3).map(\.key)
    }

    /// The auxiliaries an inverted question could take next, or nil when
    /// the sentence is not one.
    ///
    /// Fires after a question word, before any verb has been written —
    /// "what ___", "how long ___", "what time ___" — and at the very start
    /// of a sentence, where "are you free today" begins.
    private func invertedAuxiliaries(after sentence: String) -> [String]? {
        let words = Grammar.words(in: sentence)
        guard words.count <= 3 else { return nil }
        let questionWords: Set<String> = ["what", "where", "when", "who", "why", "how"]
        let opensAQuestion = words.first.map { questionWords.contains($0) } ?? false
        guard opensAQuestion || words.isEmpty else { return nil }
        // Nothing to offer once the sentence already has its verb.
        guard !words.contains(where: { Grammar.baseForm(of: $0) != nil }) else { return nil }
        // `are` first: most messages are addressed to somebody, and the
        // subject of a question you send someone is usually them.
        return words.isEmpty ? ["are", "can", "did"] : ["are", "is", "did"]
    }

    /// What tends to follow a word, from learned pairs first and the
    /// shipped seeds behind them. Shared with the suggestion bar's own
    /// ranking so both answer from the same evidence.
    func bigramScores(after previous: String) -> [String: Int] {
        var scores: [String: Int] = [:]
        let prefix = "\(previous)|"
        for (key, count) in learning.bigrams where key.hasPrefix(prefix) {
            scores[String(key.dropFirst(prefix.count)).lowercased(), default: 0] += count * 10
        }
        for (i, word) in (seedBigrams[previous] ?? []).enumerated() {
            scores[word.lowercased(), default: 0] += 3 - i
        }
        for (word, score) in assistScores(after: previous) {
            scores[word, default: 0] += score
        }
        for (word, count) in learning.screen {
            scores[word.lowercased(), default: 0] += min(count, 3)
        }
        return scores
    }
}
