import Foundation
import NaturalLanguage

/// Where a word belongs on the board, decided on device.
///
/// Named-entity recognition needs a sentence: asked about a bare word,
/// Apple's tagger calls "John" an OtherWord, "Singapore" not a place, and
/// "Fadillah" an adjective. Putting the word into carrier sentences fixes
/// almost all of that — the same tagger then reads Hafiz, Ratna, Fadillah
/// and John as people, and Singapore, Suria and Paris as places, while
/// still correctly refusing "pizza" and "satay".
enum WordFiling {
    /// Sentences chosen so each puts the word in a position that a
    /// different entity type naturally occupies.
    private static let carriers = [
        "%@ is coming to lunch with us.",
        "I met %@ yesterday at the park.",
        "We are going to %@ on Friday.",
    ]

    /// "People", "Places", "Actions", or nil when the evidence is weak.
    /// Nil is a real answer: a word filed into the wrong category is worse
    /// than one that stays only in Mine, where the user put it.
    static func category(for word: String) -> String? {
        guard !word.contains(" "), word.count >= 2 else { return nil }
        let subject = word.capitalized

        var person = 0
        var place = 0
        for carrier in carriers {
            switch entity(of: subject, in: String(format: carrier, subject)) {
            case .personalName: person += 1
            case .placeName: place += 1
            default: break
            }
        }
        if person > 0 || place > 0 {
            return person >= place ? "People" : "Places"
        }

        // No entity signal: fall back to part of speech, which does work on
        // a bare word. Verbs are the only class with a board of their own.
        let lower = word.lowercased()
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = lower
        let (tag, _) = tagger.tag(at: lower.startIndex, unit: .word, scheme: .lexicalClass)
        return tag == .verb ? "Actions" : nil
    }

    private static func entity(of target: String, in sentence: String) -> NLTag? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        var found: NLTag?
        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            if String(sentence[range]).caseInsensitiveCompare(target) == .orderedSame, let tag {
                found = tag
                return false
            }
            return true
        }
        return found
    }
}

/// Verb forms that follow the sentence, the way TouchChat's boards do: type
/// "I am" and the `go` key becomes `going`, in the same cell it has always
/// been. This is relabeling in place — the same mechanism language
/// switching already uses — so grid positions never move (invariant 1) and
/// muscle memory survives. The user aims at the same square and gets the
/// word that actually fits the sentence, instead of typing "I am go" and
/// having to fix it letter by letter.
///
/// English only. Malay marks tense with separate particles rather than by
/// inflecting the verb, so `.base` is always correct there and the Malay
/// board is deliberately left alone (invariant 8: no unverified strings).
enum Grammar {

    /// When the sentence happens.
    ///
    /// Read from the sentence rather than set on a control key: the board
    /// carries only the keys in the team's design, so tense has to come
    /// from words the user was going to tap anyway. English marks tense on
    /// the verb, but a time word is what disambiguates it — "yesterday I
    /// went", "tomorrow I will go" — so a temporal adverb anywhere in the
    /// current sentence puts every verb key into that tense.
    enum Tense { case present, past, future }

    /// Time words that place the sentence. Auxiliaries are deliberately
    /// absent: "was", "were", "have" and "will" are already handled as
    /// auxiliaries below, and listing them twice would fight that.
    private static let pastMarkers: Set<String> =
        ["yesterday", "before", "ago", "earlier", "then", "used"]
    private static let futureMarkers: Set<String> =
        ["tomorrow", "later", "soon", "next", "tonight"]

    /// The tense the current sentence is in. Only the current one: the
    /// context window still holds everything typed before it, and
    /// "yesterday" in the last sentence must not reach into this one.
    static func tense(in context: String) -> Tense {
        // The nearest marker wins — a sentence is allowed to change its
        // mind ("yesterday I was tired, tomorrow I will be fine").
        for word in words(in: currentSentence(context)).reversed() {
            if pastMarkers.contains(word) { return .past }
            if futureMarkers.contains(word) { return .future }
        }
        return .present
    }

    private static func currentSentence(_ context: String) -> String {
        guard let end = context.lastIndex(where: { ".!?\n".contains($0) }) else { return context }
        return String(context[context.index(after: end)...])
    }

    /// The form the next verb should take, from the words already typed
    /// and the chosen tense.
    enum VerbForm {
        case base            // I go, to go, don't go
        case thirdPerson     // he goes
        case progressive     // I am going
        case pastSimple      // I went
        case pastParticiple  // I have gone
        case future          // I will go
    }

    /// Auxiliaries that put the next verb in the -ing form.
    private static let progressiveAuxiliaries: Set<String> =
        ["am", "is", "are", "was", "were", "being", "i'm", "you're", "he's", "she's", "it's", "we're", "they're"]

    /// Words that pin the next verb to its plain base form whatever tense
    /// is selected, because they have already said when: modals, "to",
    /// negations. "I will went" is not a sentence anyone wants.
    private static let baseTriggers: Set<String> = [
        "to", "will", "would", "can", "could", "should", "must", "may", "might", "shall",
        "don't", "doesn't", "didn't", "won't", "can't", "let", "please", "help",
    ]

    /// Subjects that take the -s form. Subjects say who, never when, so
    /// after one of these the selected tense decides the form.
    private static let thirdPersonSubjects: Set<String> = ["he", "she", "it", "mum", "dad", "everyone", "who"]

    /// Auxiliaries that call for the past participle.
    private static let perfectAuxiliaries: Set<String> = ["have", "has", "had", "i've", "you've", "we've", "they've"]

    /// The copula, which no suffix rule can ever produce and which every
    /// AAC vendor uses as the canonical demonstration of this feature
    /// ("after you write 'I', 'be' changes to 'am'"). It needs its own
    /// table because it inflects for person as well as tense — the only
    /// English verb that still does.
    private static let copula: [VerbForm: [String: String]] = [
        .base: ["i": "am", "he": "is", "she": "is", "it": "is",
                "you": "are", "we": "are", "they": "are"],
        .pastSimple: ["i": "was", "he": "was", "she": "was", "it": "was",
                      "you": "were", "we": "were", "they": "were"],
    ]

    private static let copulaForms: Set<String> =
        ["be", "am", "is", "are", "was", "were", "been", "being"]

    /// Irregular verbs among the shipped vocabulary, plus the handful a user
    /// is most likely to add. Anything absent falls through to the regular
    /// rules below, which are correct for the vast majority of English verbs.
    /// Each entry: base -> (thirdPerson, progressive, past, pastParticiple)
    private static let irregular: [String: (String, String, String, String)] = [
        "go":     ("goes", "going", "went", "gone"),
        "eat":    ("eats", "eating", "ate", "eaten"),
        "drink":  ("drinks", "drinking", "drank", "drunk"),
        "write":  ("writes", "writing", "wrote", "written"),
        "make":   ("makes", "making", "made", "made"),
        "give":   ("gives", "giving", "gave", "given"),
        "get":    ("gets", "getting", "got", "got"),
        "come":   ("comes", "coming", "came", "come"),
        "read":   ("reads", "reading", "read", "read"),
        "draw":   ("draws", "drawing", "drew", "drawn"),
        "see":    ("sees", "seeing", "saw", "seen"),
        "take":   ("takes", "taking", "took", "taken"),
        "sleep":  ("sleeps", "sleeping", "slept", "slept"),
        "buy":    ("buys", "buying", "bought", "bought"),
        "have":   ("has", "having", "had", "had"),
        "do":     ("does", "doing", "did", "done"),
        "say":    ("says", "saying", "said", "said"),
        "feel":   ("feels", "feeling", "felt", "felt"),
        "leave":  ("leaves", "leaving", "left", "left"),
        "sit":    ("sits", "sitting", "sat", "sat"),
        "stand":  ("stands", "standing", "stood", "stood"),
        "run":    ("runs", "running", "ran", "run"),
        "put":    ("puts", "putting", "put", "put"),
    ]

    /// Verbs that never inflect here: modals have no -ing or -s form, and
    /// "can" sits on the home board as a modal, not as a main verb.
    private static let invariable: Set<String> = ["can", "will", "must", "should", "would", "may", "might"]

    /// Reads the tail of what has been typed and decides which form the next
    /// verb should take. Only the last one or two words matter, which keeps
    /// this cheap enough to run on every keystroke.
    /// The subject the sentence is about, when the last word names one.
    /// Only the copula needs this; every other English verb collapses
    /// person into a single form.
    static func subject(before context: String) -> String? {
        words(in: context).last.flatMap { copula[.base]?[$0] != nil ? $0 : nil }
    }

    private static func words(in context: String) -> [String] {
        context
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }

    /// Auxiliary first, then tense. An auxiliary already in the text is an
    /// unambiguous instruction and always wins — after "I am" the verb is
    /// -ing, and after "will" it stays base, whatever time words are
    /// around. Everything else is a subject or nothing at all, and there
    /// the sentence's tense decides.
    ///
    /// `tense` is normally left to the sentence; passing it explicitly is
    /// what a tense control key would do, if the board ever gets one.
    static func verbForm(after context: String, tense explicit: Tense? = nil) -> VerbForm {
        let sentence = currentSentence(context)
        let tense = explicit ?? self.tense(in: sentence)
        let words = words(in: sentence)
        guard let last = words.last else { return form(for: tense, thirdPerson: false) }

        // "I am not going", "he is never eating" — an adverb between the
        // auxiliary and the verb must not break the agreement.
        let adverbs: Set<String> = ["not", "never", "always", "still", "just", "really", "also"]
        let effective = adverbs.contains(last) && words.count >= 2 ? words[words.count - 2] : last

        if progressiveAuxiliaries.contains(effective) { return .progressive }
        if perfectAuxiliaries.contains(effective) { return .pastParticiple }
        if baseTriggers.contains(effective) { return .base }
        return form(for: tense, thirdPerson: thirdPersonSubjects.contains(effective))
    }

    private static func form(for tense: Tense, thirdPerson: Bool) -> VerbForm {
        switch tense {
        case .present: return thirdPerson ? .thirdPerson : .base
        case .past: return .pastSimple
        case .future: return .future
        }
    }

    /// The verb in the requested form. Falls back to the base word whenever
    /// a rule would be a guess — a wrong word in a fixed position is worse
    /// than an uninflected one.
    static func inflect(_ verb: String, as form: VerbForm, subject: String? = nil) -> String {
        let lower = verb.lowercased()
        guard !invariable.contains(lower), !verb.contains(" ") else { return verb }

        // "be" is answered by the subject, not by the tense rules alone:
        // after "I" it is "am", after "they" it is "are", after nothing at
        // all it stays "be" ("I want to be").
        if copulaForms.contains(lower) {
            switch form {
            case .progressive: return "being"
            case .pastParticiple: return "been"
            case .future: return "will be"
            case .pastSimple:
                return subject.flatMap { copula[.pastSimple]?[$0] } ?? "was"
            case .base, .thirdPerson:
                return subject.flatMap { copula[.base]?[$0] } ?? "be"
            }
        }

        if let forms = irregular[lower] {
            switch form {
            case .base: return verb
            case .thirdPerson: return forms.0
            case .progressive: return forms.1
            case .pastSimple: return forms.2          // "I went", "I ate"
            case .pastParticiple: return forms.3      // "I have gone", "I have eaten"
            case .future: return "will " + verb
            }
        }

        switch form {
        case .base: return verb
        case .thirdPerson: return thirdPersonForm(lower)
        case .progressive: return progressiveForm(lower)
        // Regular verbs spell the simple past and the participle the same
        // way — "I walked", "I have walked" — which is why only the
        // irregular table needs to tell them apart.
        case .pastSimple, .pastParticiple: return pastForm(lower)
        case .future: return "will " + verb
        }
    }

    private static func thirdPersonForm(_ verb: String) -> String {
        if verb.hasSuffix("s") || verb.hasSuffix("sh") || verb.hasSuffix("ch")
            || verb.hasSuffix("x") || verb.hasSuffix("z") || verb.hasSuffix("o") {
            return verb + "es"
        }
        if verb.hasSuffix("y"), let before = verb.dropLast().last, !isVowel(before) {
            return verb.dropLast() + "ies"
        }
        return verb + "s"
    }

    private static func progressiveForm(_ verb: String) -> String {
        if verb.hasSuffix("ie") { return verb.dropLast(2) + "ying" }        // lie -> lying
        if verb.hasSuffix("e"), !verb.hasSuffix("ee"), verb.count > 2 {
            return verb.dropLast() + "ing"                                  // make -> making
        }
        if shouldDoubleFinalConsonant(verb) { return verb + String(verb.last!) + "ing" }
        return verb + "ing"
    }

    private static func pastForm(_ verb: String) -> String {
        if verb.hasSuffix("e") { return verb + "d" }
        if verb.hasSuffix("y"), let before = verb.dropLast().last, !isVowel(before) {
            return verb.dropLast() + "ied"
        }
        if shouldDoubleFinalConsonant(verb) { return verb + String(verb.last!) + "ed" }
        return verb + "ed"
    }

    /// CVC one-syllable verbs double the final consonant: stop -> stopping,
    /// sit -> sitting. w/x/y never double.
    private static func shouldDoubleFinalConsonant(_ verb: String) -> Bool {
        let characters = Array(verb)
        guard characters.count >= 3 else { return false }
        let last = characters[characters.count - 1]
        let middle = characters[characters.count - 2]
        let first = characters[characters.count - 3]
        guard !isVowel(last), !"wxy".contains(last) else { return false }
        guard isVowel(middle), !isVowel(first) else { return false }
        // Only single-syllable verbs; a rough but reliable proxy is length.
        return characters.count <= 4
    }

    private static func isVowel(_ character: Character) -> Bool {
        "aeiou".contains(character)
    }
}
