import Foundation

// MARK: - Vocabulary


enum WordClass {
    case pronoun, verb, descriptor, noun, social, question, function, punct
}

/// A cell is one concept with one grid position.
///
/// English only. The Malay drafts this carried were removed for the MVP
/// (team decision, 10 Aug 2026): they were never verified by a native
/// speaker, and an unverified word in a fixed position is worse than no
/// word — he cannot tell the board it is wrong. They are in git history
/// if the feature comes back.
struct VocabWord {
    let text: String
    let emoji: String?
    let wordClass: WordClass

    init(_ text: String, emoji: String? = nil, _ wordClass: WordClass) {
        self.text = text
        self.emoji = emoji
        self.wordClass = wordClass
    }
}

struct Category {
    let name: String
    let words: [VocabWord]
}

let vocabulary: [Category] = [
    Category(name: "Core", words: [
        VocabWord("I", emoji: "🙋", .pronoun), VocabWord("you", emoji: "👉", .pronoun),
        VocabWord("want", emoji: "🤲", .verb), VocabWord("like", emoji: "❤️", .verb),
        VocabWord("go", emoji: "🚶", .verb), VocabWord("help", emoji: "🤝", .verb),
        VocabWord("more", emoji: "➕", .descriptor), VocabWord("stop", emoji: "✋", .verb),
        VocabWord("yes", emoji: "✅", .social), VocabWord("no", emoji: "❌", .social),
        VocabWord("not", emoji: "🚫", .descriptor), VocabWord("this", emoji: "👇", .pronoun),
        VocabWord("that", .pronoun), VocabWord("good", emoji: "👍", .descriptor),
        VocabWord("bad", emoji: "👎", .descriptor), VocabWord("now", emoji: "⏰", .descriptor),
        VocabWord("later", emoji: "🕒", .descriptor), VocabWord("what", emoji: "❓", .question),
        VocabWord("where", emoji: "📍", .question), VocabWord("when", .question),
        VocabWord("who", .question), VocabWord("can", emoji: "💪", .verb),
        VocabWord(".", .punct), VocabWord("?", .punct),
        // Appended, never inserted (invariant 1). These six are what make
        // grammar reachable at all: without a subject to agree with and an
        // auxiliary to follow, the verb keys have nothing to respond to and
        // the board looks frozen. "be" is the one every AAC vendor uses to
        // demonstrate the feature — write "I" and it reads "am".
        // Malay: unverified drafts. Malay has no present-tense copula, so
        // "adalah" is a formal approximation and needs Fadillah's read.
        VocabWord("he", .pronoun), VocabWord("she", .pronoun),
        VocabWord("it", .pronoun), VocabWord("be", .verb),
        VocabWord("do", .verb), VocabWord("have", .verb),
        // Time words, and they do double duty: they are ordinary
        // vocabulary AND they are how the board knows what tense it is in.
        // The design has no tense control and gets no extra key, so
        // "yesterday" is what turns `go` into `went` and `be` into `was` —
        // which is how English works anyway, since the verb ending is
        // ambiguous and the adverb is what actually places the sentence.
        VocabWord("will", .verb),
        VocabWord("time", emoji: "🕐", .noun),
        VocabWord("yesterday", .descriptor),
        VocabWord("tomorrow", .descriptor),
        VocabWord("today", .descriptor),
    ]),
    Category(name: "People", words: [
        VocabWord("I", emoji: "🙋", .pronoun), VocabWord("you", emoji: "👉", .pronoun),
        VocabWord("Mum", emoji: "👩", .noun), VocabWord("Dad", emoji: "👨", .noun),
        VocabWord("brother", emoji: "👦", .noun), VocabWord("sister", emoji: "👧", .noun),
        VocabWord("friend", emoji: "🧑‍🤝‍🧑", .noun), VocabWord("teacher", emoji: "🧑‍🏫", .noun),
        VocabWord("doctor", emoji: "🧑‍⚕️", .noun), VocabWord("everyone", emoji: "👥", .noun),
        VocabWord("we", .pronoun), VocabWord("they", .pronoun),
    ]),
    Category(name: "Actions", words: [
        VocabWord("eat", emoji: "🍽️", .verb), VocabWord("drink", emoji: "🥤", .verb),
        VocabWord("play", emoji: "🎮", .verb), VocabWord("watch", emoji: "📺", .verb),
        VocabWord("draw", emoji: "🎨", .verb), VocabWord("read", emoji: "📖", .verb),
        VocabWord("write", emoji: "✍️", .verb), VocabWord("make", emoji: "🛠️", .verb),
        VocabWord("open", .verb), VocabWord("close", .verb),
        VocabWord("give", .verb), VocabWord("get", .verb),
        VocabWord("come", .verb), VocabWord("look", emoji: "👀", .verb),
        VocabWord("listen", emoji: "👂", .verb), VocabWord("wait", emoji: "⏳", .verb),
        // Measured: every word below was spelled letter by letter in the
        // tap-cost corpus. Malay unverified.
        VocabWord("see", emoji: "👁️", .verb),
        VocabWord("understand", .verb),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("take", .verb), VocabWord("buy", emoji: "🛍️", .verb),
        VocabWord("borrow", .verb), VocabWord("find", .verb),
        VocabWord("try", .verb), VocabWord("sleep", emoji: "😴", .verb),
        VocabWord("stay", .verb), VocabWord("work", .verb),
        VocabWord("turn", .verb),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("love", emoji: "❤️", .verb),
        VocabWord("win", emoji: "🏆", .verb),
        VocabWord("forget", .verb), VocabWord("remember", .verb),
        VocabWord("miss", .verb),
        VocabWord("finish", .verb), VocabWord("start", .verb),
        VocabWord("need", .verb),
    ]),
    Category(name: "Feelings", words: [
        VocabWord("happy", emoji: "😊", .descriptor), VocabWord("sad", emoji: "😢", .descriptor),
        VocabWord("angry", emoji: "😠", .descriptor), VocabWord("tired", emoji: "😴", .descriptor),
        VocabWord("excited", emoji: "🤩", .descriptor), VocabWord("scared", emoji: "😨", .descriptor),
        VocabWord("bored", emoji: "🥱", .descriptor), VocabWord("sick", emoji: "🤒", .descriptor),
        VocabWord("hungry", emoji: "😋", .descriptor), VocabWord("thirsty", emoji: "🥵", .descriptor),
        VocabWord("okay", emoji: "🙆", .descriptor), VocabWord("great", emoji: "🌟", .descriptor),
        // "my head hurts" had to be spelled a letter at a time, which is
        // sixteen taps to report pain. Malay unverified.
        VocabWord("hurt", emoji: "🤕", .verb),
        VocabWord("head", emoji: "🧠", .noun),
        VocabWord("tummy", .noun),
        VocabWord("very", .descriptor),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("better", .descriptor), VocabWord("well", .descriptor),
        VocabWord("fine", .descriptor), VocabWord("proud", emoji: "🥹", .descriptor),
        VocabWord("alone", .descriptor), VocabWord("hard", .descriptor),
        VocabWord("easy", .descriptor), VocabWord("ready", .descriptor),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("loud", emoji: "🔊", .descriptor), VocabWord("fair", .descriptor),
        VocabWord("free", .descriptor), VocabWord("fast", .descriptor),
        VocabWord("short", .descriptor), VocabWord("maybe", .descriptor),
        VocabWord("late", .descriptor), VocabWord("sorry", .social),
        VocabWord("feel", .verb),
    ]),
    Category(name: "Food", words: [
        VocabWord("water", emoji: "💧", .noun), VocabWord("rice", emoji: "🍚", .noun),
        VocabWord("chicken", emoji: "🍗", .noun), VocabWord("noodles", emoji: "🍜", .noun),
        VocabWord("bread", emoji: "🍞", .noun), VocabWord("fruit", emoji: "🍎", .noun),
        VocabWord("banana", emoji: "🍌", .noun), VocabWord("juice", emoji: "🧃", .noun),
        VocabWord("milk", emoji: "🥛", .noun), VocabWord("tea", emoji: "🍵", .noun),
        VocabWord("biryani", emoji: "🍛", .noun), VocabWord("chocolate", emoji: "🍫", .noun),
        // Measured, not guessed: six real sentences were run through the
        // board and every noun that had to be spelled letter by letter was
        // recorded. These were among them. Malay unverified.
        VocabWord("breakfast", emoji: "🥐", .noun),
        VocabWord("lunch", emoji: "🍱", .noun),
        VocabWord("dinner", emoji: "🍲", .noun),
        // Measured against 200 sentences. `food` is the one this category
        // was named after and did not contain.
        VocabWord("food", emoji: "🍽️", .noun),
        VocabWord("snack", emoji: "🍪", .noun),
        VocabWord("egg", emoji: "🥚", .noun),
        VocabWord("fish", emoji: "🐟", .noun),
        VocabWord("cake", emoji: "🍰", .noun),
        VocabWord("ice cream", emoji: "🍦", .noun),
    ]),
    Category(name: "Places", words: [
        VocabWord("home", emoji: "🏠", .noun), VocabWord("school", emoji: "🏫", .noun),
        VocabWord("outside", emoji: "🌳", .noun), VocabWord("shop", emoji: "🛒", .noun),
        VocabWord("park", emoji: "🏞️", .noun), VocabWord("bus", emoji: "🚌", .noun),
        VocabWord("MRT", emoji: "🚇", .noun), VocabWord("restaurant", emoji: "🍔", .noun),
        VocabWord("hospital", emoji: "🏥", .noun), VocabWord("toilet", emoji: "🚻", .noun),
        VocabWord("bed", emoji: "🛏️", .noun), VocabWord("room", .noun),
        VocabWord("nurse", emoji: "🧑‍⚕️", .noun),
        VocabWord("here", .descriptor), VocabWord("there", .descriptor),
    ]),
    Category(name: "Art", words: [
        VocabWord("draw", emoji: "🎨", .verb), VocabWord("paint", emoji: "🖌️", .verb),
        VocabWord("color", emoji: "🌈", .noun), VocabWord("picture", emoji: "🖼️", .noun),
        VocabWord("comic", emoji: "📚", .noun), VocabWord("monster", emoji: "👾", .noun),
        VocabWord("idea", emoji: "💡", .noun), VocabWord("cool", emoji: "😎", .descriptor),
        VocabWord("funny", emoji: "😂", .descriptor), VocabWord("new", emoji: "✨", .descriptor),
        VocabWord("finished", emoji: "🏁", .descriptor), VocabWord("show you", emoji: "👀", .social),
        VocabWord("story", emoji: "📖", .noun),
        VocabWord("song", emoji: "🎶", .noun),
        VocabWord("book", emoji: "📕", .noun), VocabWord("pen", emoji: "🖊️", .noun),
        VocabWord("paper", emoji: "📄", .noun), VocabWord("dragon", emoji: "🐉", .noun),
        VocabWord("hug", emoji: "🤗", .noun), VocabWord("rain", emoji: "🌧️", .noun),
        VocabWord("space", emoji: "🚀", .noun),
        VocabWord("drawing", .noun),
        VocabWord("homework", emoji: "📓", .noun),
    ]),
    // Browsing is its own vocabulary: the words that move you around a page
    // or a video are almost none of the words you use to talk to a person,
    // and typing them letter by letter is exactly the cost this keyboard
    // exists to remove.
    Category(name: "Web", words: [
        VocabWord("search", emoji: "🔍", .verb), VocabWord("open", .verb),
        VocabWord("watch", emoji: "📺", .verb), VocabWord("play", emoji: "▶️", .verb),
        VocabWord("next", emoji: "⏭️", .descriptor), VocabWord("back", emoji: "◀️", .descriptor),
        VocabWord("video", emoji: "🎬", .noun), VocabWord("music", emoji: "🎵", .noun),
        VocabWord("news", emoji: "📰", .noun), VocabWord("game", emoji: "🎮", .noun),
        VocabWord("YouTube", emoji: "▶️", .noun), VocabWord("Google", emoji: "🔎", .noun),
        VocabWord("link", emoji: "🔗", .noun), VocabWord("page", emoji: "📄", .noun),
        VocabWord("share", emoji: "📤", .verb), VocabWord("download", emoji: "⬇️", .verb),
        VocabWord("www.", .noun), VocabWord(".com", .noun),
        VocabWord("how to", .question), VocabWord("what is", .question),
        VocabWord("computer", emoji: "💻", .noun),
        VocabWord("answer", .noun), VocabWord("question", emoji: "❓", .noun),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("name", .noun), VocabWord("day", .noun),
        VocabWord("thing", .noun), VocabWord("joke", emoji: "😄", .noun),
        VocabWord("weather", emoji: "🌤️", .noun), VocabWord("birthday", emoji: "🎂", .noun),
        VocabWord("photo", emoji: "📷", .noun),
    ]),
    Category(name: "Chat", words: [
        VocabWord("hello", emoji: "👋", .social), VocabWord("bye", emoji: "👋", .social),
        VocabWord("please", emoji: "🙏", .social), VocabWord("thank you", emoji: "🙏", .social),
        VocabWord("sorry", .social), VocabWord("how are you", .social),
        VocabWord("I'm good", .social), VocabWord("wait a moment", emoji: "⏳", .social),
        VocabWord("nice to meet you", .social), VocabWord("see you later", .social),
        VocabWord("I use this to talk", emoji: "💬", .social),
        VocabWord("good morning", emoji: "🌅", .social),
        VocabWord("good night", emoji: "🌙", .social),
        // The talking verbs live with the talking, which is both where
        // they belong and what keeps Actions inside one page. Actions had
        // grown to 44 words on a board that shows 35, and the nine over
        // the line would have vanished without a gap or a crash — the
        // failure mode that cost us the `be` key for a whole build.
        VocabWord("say", .verb), VocabWord("speak", .verb),
        VocabWord("tell", .verb), VocabWord("ask", .verb),
        VocabWord("hear", .verb), VocabWord("talk", emoji: "💬", .verb),
        VocabWord("explain", .verb), VocabWord("send", emoji: "📤", .verb),
        VocabWord("show", .verb),
        VocabWord("haha", emoji: "😂", .social),
    ]),
    // The closed classes, on a board of their own.
    //
    // They lived at the end of Core, where nothing could reach them: a
    // four-row board shows 36 cells and Core had grown to 54, so the packer
    // dropped the last 18 without a word. "of", "from", "out", "up", "but",
    // "or", "because", "a", "the", "me" and "again" existed in the app and
    // appeared on no board anywhere.
    //
    // These are the words that turn a board of labels into sentences — "I
    // am waiting" is a dead end without "for" — so they get the space they
    // need rather than the space that was left over. Core word lists
    // (Banajee; Boenisch & Soto) rank them among the highest-frequency
    // words in anything anyone says, and every published core board carries
    // them permanently.
    //
    // Malay: unverified drafts, and weaker here than anywhere else. Malay
    // preposition boundaries do not line up with English ones, possession
    // is postposed ("kawan saya"), and Malay has no articles at all — "a"
    // and "the" have no Malay cell and are left in English rather than
    // invented. The category name is a draft too. Needs Fadillah.
    Category(name: "Little words", words: [
        VocabWord("to", .function), VocabWord("for", .function),
        VocabWord("with", .function), VocabWord("in", .function),
        VocabWord("on", .function), VocabWord("at", .function),
        VocabWord("of", .function), VocabWord("from", .function),
        VocabWord("out", .function), VocabWord("up", .function),
        VocabWord("and", .function), VocabWord("but", .function),
        VocabWord("or", .function), VocabWord("because", .function),
        VocabWord("a", .function), VocabWord("the", .function),
        VocabWord("my", .pronoun), VocabWord("me", .pronoun),
        VocabWord("we", .pronoun), VocabWord("they", .pronoun),
        VocabWord("again", emoji: "🔁", .descriptor),
        // `about` was the most frequently spelled word in the whole
        // tap-cost corpus — "a story about a monster", "videos about
        // space" — and it was in no category at all. `how` completes the
        // question words; it is here rather than in Core because Core has
        // exactly one free cell and `today` earned it. Malay unverified.
        VocabWord("about", .function),
        VocabWord("how", .question),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("much", .descriptor), VocabWord("some", .function),
        VocabWord("too", .descriptor), VocabWord("long", .descriptor),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("many", .descriptor), VocabWord("a lot", .descriptor),
        VocabWord("yet", .descriptor), VocabWord("one", .descriptor),
        VocabWord("so", .descriptor), VocabWord("until", .function),
        VocabWord("your", .pronoun),
    ]),
]

/// Lookup by text, so Recents keeps colour and emoji for a word however
/// it got there.
let vocabIndex: [String: VocabWord] = {
    var index: [String: VocabWord] = [:]
    for category in vocabulary {
        for word in category.words {
            if index[word.text] == nil { index[word.text] = word }
        }
    }
    return index
}()

/// The nouns the board can produce, lowercased and in both languages.
///
/// Grammar reads this to answer a question no suffix rule can: is the word
/// in front of the verb a subject? "my head ___" and "what time ___" both
/// want third-person singular agreement — `hurts`, `is` — and both were
/// falling through to the base form because the only subjects Grammar
/// recognised were the seven pronouns and four names written into it by
/// hand. Reading the vocabulary instead means every noun added to a
/// category can be a sentence's subject the moment it exists.
let nounWords: Set<String> = {
    var nouns: Set<String> = []
    for category in vocabulary {
        for word in category.words where word.wordClass == .noun {
            nouns.insert(word.text.lowercased())
        }
    }
    return nouns
}()

/// How each word is actually spelled, found from a lowercased one.
///
/// Analysis lowercases everything so "Mum" and "mum" are the same word;
/// writing a sentence back out has to undo that, or the keyboard offers
/// "Where is mum?" and "Does mrt go there?" — which is not what anyone
/// would write, and looks like a machine wrote it.
let canonicalSpelling: [String: String] = {
    var spelling: [String: String] = [:]
    for category in vocabulary {
        for word in category.words {
            spelling[word.text.lowercased()] = word.text
        }
    }
    return spelling
}()

/// The words that describe rather than name, lowercased. The copula is
/// what English demands between a subject and one of these, and it is the
/// word an AAC user drops first — "I hungry", "that funny". Knowing which
/// words are descriptors is what lets a rephrasing put it back without
/// guessing at words it does not recognise.
let descriptorWords: Set<String> = {
    var described: Set<String> = []
    for category in vocabulary {
        for word in category.words where word.wordClass == .descriptor {
            described.insert(word.text.lowercased())
        }
    }
    return described
}()

/// The places you can go to, which is the one case where the missing
/// preposition is never in doubt: "I go park" means "go TO THE park".
let placeWords: Set<String> = {
    guard let places = vocabulary.first(where: { $0.name == "Places" }) else { return [] }
    return Set(places.words.filter { $0.wordClass == .noun }.map { $0.text.lowercased() })
}()

/// Seed bigrams per language so prediction is useful before any learning.
let seedBigrams: [String: [String]] = [
    "": ["I", "you", "hello"],
    "i": ["want", "like", "need"],
    "you": ["can", "want", "okay"],
    "want": ["more", "that", "food"],
    "like": ["this", "that", "it"],
    "can": ["you", "we", "help"],
    "go": ["home", "outside", "now"],
    "help": ["me", "please"],
    "more": ["please", "time"],
    "what": ["time", "happened"],
    "where": ["are", "is"],
    "not": ["good", "now", "yet"],
    "this": ["is", "one"],
    "that": ["is", "one"],
    "eat": ["rice", "chicken", "now"],
    "drink": ["water", "juice", "tea"],
    "draw": ["monster", "picture", "now"],
    "watch": ["video", "music", "game"],
    "write": ["story", "homework", "song"],
    "read": ["story", "comic", "news"],
    "play": ["game", "music", "outside"],
    "have": ["lunch", "dinner", "time"],
    "my": ["Mum", "friend", "idea"],
    "thank": ["you"],
    "how": ["are you"],
]

// MARK: - Controller

