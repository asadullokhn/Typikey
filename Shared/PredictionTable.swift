import Foundation

/// What a model said, written down where the keyboard can read it.
///
/// The keyboard makes no network calls — not with Full Access, not without
/// it, not ever (invariant 5). That is not a limitation to work around: what
/// he types IS his speech, he cannot audit where it goes, and consent to
/// send it would be given on his behalf, permanently. So the rule stands and
/// the model goes on the other side of it.
///
/// The app can reach a network. It runs while somebody is holding it, asks a
/// model about the contexts he actually uses, and writes the answers here.
/// The keyboard then does a dictionary lookup — microseconds, no memory, no
/// connection, and nothing about the sentence he is typing right now leaves
/// the device.
///
/// The cost of that trade is honest and worth stating: this cannot answer a
/// context nobody anticipated. It is a cache of a model's judgement, not the
/// model. Live inference in the keyboard would need invariant 5 relaxed, and
/// that is the team's decision, not this file's.
struct PredictionTable: Codable, Equatable {
    /// Bumped when the shape changes. A keyboard that meets a table it does
    /// not understand ignores it rather than guessing — an old build reading
    /// a new table must degrade to the shipped board, never to a broken one.
    static let currentVersion = 1

    var version = currentVersion

    /// Anchor word, lowercased — `""` for the start of a sentence — to the
    /// words that tend to follow it. Feeds the suggestion bar and the spare
    /// cells through the same scoring everything else uses.
    var continuations: [String: [String]] = [:]

    /// Sentence so far, lowercased and trimmed, to whole utterances that
    /// finish it. `""` holds the openers. This is the half a bigram table
    /// structurally cannot do: "can I go to the toilet please" as one tap
    /// rather than seven.
    var phrases: [String: [String]] = [:]

    /// Which model produced it, and when. Shown in the app, because a
    /// suggestion whose origin cannot be named is a suggestion nobody can
    /// argue with.
    var source = ""
    var generated: Date?

    static let storeKey = "predictionTable"
    /// Both sides read this: the app to know whether to build a table, the
    /// keyboard to know whether to look at one. Off means off on both.
    static let enabledKey = "aiAssistEnabled"

    var isEmpty: Bool { continuations.isEmpty && phrases.isEmpty }

    /// The words that finish this sentence, or nil when nothing was
    /// precomputed for it.
    ///
    /// Exact match on the sentence so far. Deliberately not fuzzy: a near
    /// match would put a sentence he did not mean into a fixed position,
    /// and at thirty seconds a tap, undoing that costs more than spelling
    /// the word would have.
    func completion(after context: String) -> [String]? {
        let sentence = Grammar.currentSentence(context)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard let phrase = phrases[sentence]?.first else { return nil }
        // A stored phrase is the whole message, including the part he has
        // already written — that is what makes it readable in the app, where
        // somebody has to judge whether it is a thing he would say. What the
        // bar offers is the rest of it.
        let all = Grammar.words(in: phrase.lowercased())
        let typed = Grammar.words(in: sentence)
        guard all.count > typed.count,
              zip(all, typed).allSatisfy({ $0 == $1 })
        else { return nil }
        return Array(all.dropFirst(typed.count))
    }

    static func load(from store: UserDefaults) -> PredictionTable? {
        guard let data = store.data(forKey: storeKey),
              let table = try? JSONDecoder().decode(PredictionTable.self, from: data),
              table.version == currentVersion,
              !table.isEmpty
        else { return nil }
        return table
    }

    func save(to store: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        store.set(data, forKey: Self.storeKey)
    }

    static func clear(from store: UserDefaults) {
        store.removeObject(forKey: storeKey)
    }
}
