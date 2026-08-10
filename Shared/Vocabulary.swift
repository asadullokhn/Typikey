import Foundation

enum Lang: String {
    case en, ms // English, Malay (Bahasa Melayu) — Singapore's context

    var spellCheckCode: String {
        switch self {
        case .en: return "en_US"
        case .ms: return "ms_MY"
        }
    }
}

// MARK: - Vocabulary


enum WordClass {
    case pronoun, verb, descriptor, noun, social, question, function, punct
}

/// A cell is one concept with one grid position; language only changes
/// its label. Malay translations are drafts — verify with Fadillah
/// before putting this in front of Sayfullah.
struct VocabWord {
    let en: String
    let ms: String
    let emoji: String?
    let wordClass: WordClass

    init(_ en: String, ms: String? = nil, emoji: String? = nil, _ wordClass: WordClass) {
        self.en = en
        self.ms = ms ?? en
        self.emoji = emoji
        self.wordClass = wordClass
    }

    func text(_ lang: Lang) -> String {
        lang == .ms ? ms : en
    }
}

struct Category {
    let en: String
    let ms: String
    let words: [VocabWord]

    func name(_ lang: Lang) -> String {
        lang == .ms ? ms : en
    }
}

let vocabulary: [Category] = [
    Category(en: "Core", ms: "Teras", words: [
        VocabWord("I", ms: "saya", emoji: "🙋", .pronoun), VocabWord("you", ms: "awak", emoji: "👉", .pronoun),
        VocabWord("want", ms: "mahu", emoji: "🤲", .verb), VocabWord("like", ms: "suka", emoji: "❤️", .verb),
        VocabWord("go", ms: "pergi", emoji: "🚶", .verb), VocabWord("help", ms: "tolong", emoji: "🤝", .verb),
        VocabWord("more", ms: "lagi", emoji: "➕", .descriptor), VocabWord("stop", ms: "berhenti", emoji: "✋", .verb),
        VocabWord("yes", ms: "ya", emoji: "✅", .social), VocabWord("no", ms: "tidak", emoji: "❌", .social),
        VocabWord("not", ms: "bukan", emoji: "🚫", .descriptor), VocabWord("this", ms: "ini", emoji: "👇", .pronoun),
        VocabWord("that", ms: "itu", .pronoun), VocabWord("good", ms: "bagus", emoji: "👍", .descriptor),
        VocabWord("bad", ms: "teruk", emoji: "👎", .descriptor), VocabWord("now", ms: "sekarang", emoji: "⏰", .descriptor),
        VocabWord("later", ms: "nanti", emoji: "🕒", .descriptor), VocabWord("what", ms: "apa", emoji: "❓", .question),
        VocabWord("where", ms: "di mana", emoji: "📍", .question), VocabWord("when", ms: "bila", .question),
        VocabWord("who", ms: "siapa", .question), VocabWord("can", ms: "boleh", emoji: "💪", .verb),
        VocabWord(".", .punct), VocabWord("?", .punct),
        // Appended, never inserted (invariant 1). These six are what make
        // grammar reachable at all: without a subject to agree with and an
        // auxiliary to follow, the verb keys have nothing to respond to and
        // the board looks frozen. "be" is the one every AAC vendor uses to
        // demonstrate the feature — write "I" and it reads "am".
        // Malay: unverified drafts. Malay has no present-tense copula, so
        // "adalah" is a formal approximation and needs Fadillah's read.
        VocabWord("he", ms: "dia", .pronoun), VocabWord("she", ms: "dia", .pronoun),
        VocabWord("it", ms: "ia", .pronoun), VocabWord("be", ms: "adalah", .verb),
        VocabWord("do", ms: "buat", .verb), VocabWord("have", ms: "ada", .verb),
        // Time words, and they do double duty: they are ordinary
        // vocabulary AND they are how the board knows what tense it is in.
        // The design has no tense control and gets no extra key, so
        // "yesterday" is what turns `go` into `went` and `be` into `was` —
        // which is how English works anyway, since the verb ending is
        // ambiguous and the adverb is what actually places the sentence.
        VocabWord("will", ms: "akan", .verb),
        VocabWord("time", ms: "masa", emoji: "🕐", .noun),
        VocabWord("yesterday", ms: "semalam", .descriptor),
        VocabWord("tomorrow", ms: "esok", .descriptor),
        VocabWord("today", ms: "hari ini", .descriptor),
    ]),
    Category(en: "People", ms: "Orang", words: [
        VocabWord("I", ms: "saya", emoji: "🙋", .pronoun), VocabWord("you", ms: "awak", emoji: "👉", .pronoun),
        VocabWord("Mum", ms: "Ibu", emoji: "👩", .noun), VocabWord("Dad", ms: "Ayah", emoji: "👨", .noun),
        VocabWord("brother", ms: "abang", emoji: "👦", .noun), VocabWord("sister", ms: "kakak", emoji: "👧", .noun),
        VocabWord("friend", ms: "kawan", emoji: "🧑‍🤝‍🧑", .noun), VocabWord("teacher", ms: "cikgu", emoji: "🧑‍🏫", .noun),
        VocabWord("doctor", ms: "doktor", emoji: "🧑‍⚕️", .noun), VocabWord("everyone", ms: "semua", emoji: "👥", .noun),
        VocabWord("we", ms: "kami", .pronoun), VocabWord("they", ms: "mereka", .pronoun),
    ]),
    Category(en: "Actions", ms: "Tindakan", words: [
        VocabWord("eat", ms: "makan", emoji: "🍽️", .verb), VocabWord("drink", ms: "minum", emoji: "🥤", .verb),
        VocabWord("play", ms: "main", emoji: "🎮", .verb), VocabWord("watch", ms: "tonton", emoji: "📺", .verb),
        VocabWord("draw", ms: "lukis", emoji: "🎨", .verb), VocabWord("read", ms: "baca", emoji: "📖", .verb),
        VocabWord("write", ms: "tulis", emoji: "✍️", .verb), VocabWord("make", ms: "buat", emoji: "🛠️", .verb),
        VocabWord("open", ms: "buka", .verb), VocabWord("close", ms: "tutup", .verb),
        VocabWord("give", ms: "beri", .verb), VocabWord("get", ms: "dapat", .verb),
        VocabWord("come", ms: "datang", .verb), VocabWord("look", ms: "tengok", emoji: "👀", .verb),
        VocabWord("listen", ms: "dengar", emoji: "👂", .verb), VocabWord("wait", ms: "tunggu", emoji: "⏳", .verb),
        // Measured: every word below was spelled letter by letter in the
        // tap-cost corpus. Malay unverified.
        VocabWord("see", ms: "lihat", emoji: "👁️", .verb),
        VocabWord("understand", ms: "faham", .verb),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("take", ms: "ambil", .verb), VocabWord("buy", ms: "beli", emoji: "🛍️", .verb),
        VocabWord("borrow", ms: "pinjam", .verb), VocabWord("find", ms: "cari", .verb),
        VocabWord("try", ms: "cuba", .verb), VocabWord("sleep", ms: "tidur", emoji: "😴", .verb),
        VocabWord("stay", ms: "tinggal", .verb), VocabWord("work", ms: "kerja", .verb),
        VocabWord("turn", ms: "pusing", .verb),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("love", ms: "sayang", emoji: "❤️", .verb),
        VocabWord("win", ms: "menang", emoji: "🏆", .verb),
        VocabWord("forget", ms: "lupa", .verb), VocabWord("remember", ms: "ingat", .verb),
        VocabWord("miss", ms: "rindu", .verb),
        VocabWord("finish", ms: "habis", .verb), VocabWord("start", ms: "mula", .verb),
        VocabWord("need", ms: "perlu", .verb),
    ]),
    Category(en: "Feelings", ms: "Perasaan", words: [
        VocabWord("happy", ms: "gembira", emoji: "😊", .descriptor), VocabWord("sad", ms: "sedih", emoji: "😢", .descriptor),
        VocabWord("angry", ms: "marah", emoji: "😠", .descriptor), VocabWord("tired", ms: "penat", emoji: "😴", .descriptor),
        VocabWord("excited", ms: "teruja", emoji: "🤩", .descriptor), VocabWord("scared", ms: "takut", emoji: "😨", .descriptor),
        VocabWord("bored", ms: "bosan", emoji: "🥱", .descriptor), VocabWord("sick", ms: "sakit", emoji: "🤒", .descriptor),
        VocabWord("hungry", ms: "lapar", emoji: "😋", .descriptor), VocabWord("thirsty", ms: "haus", emoji: "🥵", .descriptor),
        VocabWord("okay", ms: "okay", emoji: "🙆", .descriptor), VocabWord("great", ms: "hebat", emoji: "🌟", .descriptor),
        // "my head hurts" had to be spelled a letter at a time, which is
        // sixteen taps to report pain. Malay unverified.
        VocabWord("hurt", ms: "sakit", emoji: "🤕", .verb),
        VocabWord("head", ms: "kepala", emoji: "🧠", .noun),
        VocabWord("tummy", ms: "perut", .noun),
        VocabWord("very", ms: "sangat", .descriptor),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("better", ms: "lebih baik", .descriptor), VocabWord("well", ms: "sihat", .descriptor),
        VocabWord("fine", ms: "baik", .descriptor), VocabWord("proud", ms: "bangga", emoji: "🥹", .descriptor),
        VocabWord("alone", ms: "sendiri", .descriptor), VocabWord("hard", ms: "susah", .descriptor),
        VocabWord("easy", ms: "senang", .descriptor), VocabWord("ready", ms: "sedia", .descriptor),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("loud", ms: "kuat", emoji: "🔊", .descriptor), VocabWord("fair", ms: "adil", .descriptor),
        VocabWord("free", ms: "lapang", .descriptor), VocabWord("fast", ms: "laju", .descriptor),
        VocabWord("short", ms: "pendek", .descriptor), VocabWord("maybe", ms: "mungkin", .descriptor),
        VocabWord("late", ms: "lewat", .descriptor), VocabWord("sorry", ms: "maaf", .social),
        VocabWord("feel", ms: "rasa", .verb),
    ]),
    Category(en: "Food", ms: "Makanan", words: [
        VocabWord("water", ms: "air", emoji: "💧", .noun), VocabWord("rice", ms: "nasi", emoji: "🍚", .noun),
        VocabWord("chicken", ms: "ayam", emoji: "🍗", .noun), VocabWord("noodles", ms: "mi", emoji: "🍜", .noun),
        VocabWord("bread", ms: "roti", emoji: "🍞", .noun), VocabWord("fruit", ms: "buah", emoji: "🍎", .noun),
        VocabWord("banana", ms: "pisang", emoji: "🍌", .noun), VocabWord("juice", ms: "jus", emoji: "🧃", .noun),
        VocabWord("milk", ms: "susu", emoji: "🥛", .noun), VocabWord("tea", ms: "teh", emoji: "🍵", .noun),
        VocabWord("biryani", ms: "briyani", emoji: "🍛", .noun), VocabWord("chocolate", ms: "coklat", emoji: "🍫", .noun),
        // Measured, not guessed: six real sentences were run through the
        // board and every noun that had to be spelled letter by letter was
        // recorded. These were among them. Malay unverified.
        VocabWord("breakfast", ms: "sarapan", emoji: "🥐", .noun),
        VocabWord("lunch", ms: "makan tengah hari", emoji: "🍱", .noun),
        VocabWord("dinner", ms: "makan malam", emoji: "🍲", .noun),
        // Measured against 200 sentences. `food` is the one this category
        // was named after and did not contain.
        VocabWord("food", ms: "makanan", emoji: "🍽️", .noun),
        VocabWord("snack", ms: "snek", emoji: "🍪", .noun),
        VocabWord("egg", ms: "telur", emoji: "🥚", .noun),
        VocabWord("fish", ms: "ikan", emoji: "🐟", .noun),
        VocabWord("cake", ms: "kek", emoji: "🍰", .noun),
        VocabWord("ice cream", ms: "aiskrim", emoji: "🍦", .noun),
    ]),
    Category(en: "Places", ms: "Tempat", words: [
        VocabWord("home", ms: "rumah", emoji: "🏠", .noun), VocabWord("school", ms: "sekolah", emoji: "🏫", .noun),
        VocabWord("outside", ms: "luar", emoji: "🌳", .noun), VocabWord("shop", ms: "kedai", emoji: "🛒", .noun),
        VocabWord("park", ms: "taman", emoji: "🏞️", .noun), VocabWord("bus", ms: "bas", emoji: "🚌", .noun),
        VocabWord("MRT", emoji: "🚇", .noun), VocabWord("restaurant", ms: "restoran", emoji: "🍔", .noun),
        VocabWord("hospital", emoji: "🏥", .noun), VocabWord("toilet", ms: "tandas", emoji: "🚻", .noun),
        VocabWord("bed", ms: "katil", emoji: "🛏️", .noun), VocabWord("room", ms: "bilik", .noun),
        VocabWord("nurse", ms: "jururawat", emoji: "🧑‍⚕️", .noun),
        VocabWord("here", ms: "sini", .descriptor), VocabWord("there", ms: "sana", .descriptor),
    ]),
    Category(en: "Art", ms: "Seni", words: [
        VocabWord("draw", ms: "lukis", emoji: "🎨", .verb), VocabWord("paint", ms: "cat", emoji: "🖌️", .verb),
        VocabWord("color", ms: "warna", emoji: "🌈", .noun), VocabWord("picture", ms: "gambar", emoji: "🖼️", .noun),
        VocabWord("comic", ms: "komik", emoji: "📚", .noun), VocabWord("monster", ms: "raksasa", emoji: "👾", .noun),
        VocabWord("idea", emoji: "💡", .noun), VocabWord("cool", ms: "menarik", emoji: "😎", .descriptor),
        VocabWord("funny", ms: "kelakar", emoji: "😂", .descriptor), VocabWord("new", ms: "baru", emoji: "✨", .descriptor),
        VocabWord("finished", ms: "siap", emoji: "🏁", .descriptor), VocabWord("show you", ms: "tunjuk", emoji: "👀", .social),
        VocabWord("story", ms: "cerita", emoji: "📖", .noun),
        VocabWord("song", ms: "lagu", emoji: "🎶", .noun),
        VocabWord("book", ms: "buku", emoji: "📕", .noun), VocabWord("pen", ms: "pen", emoji: "🖊️", .noun),
        VocabWord("paper", ms: "kertas", emoji: "📄", .noun), VocabWord("dragon", ms: "naga", emoji: "🐉", .noun),
        VocabWord("hug", ms: "peluk", emoji: "🤗", .noun), VocabWord("rain", ms: "hujan", emoji: "🌧️", .noun),
        VocabWord("space", ms: "angkasa", emoji: "🚀", .noun),
        VocabWord("drawing", ms: "lukisan", .noun),
        VocabWord("homework", ms: "kerja rumah", emoji: "📓", .noun),
    ]),
    // Browsing is its own vocabulary: the words that move you around a page
    // or a video are almost none of the words you use to talk to a person,
    // and typing them letter by letter is exactly the cost this keyboard
    // exists to remove.
    Category(en: "Web", ms: "Web", words: [
        VocabWord("search", ms: "cari", emoji: "🔍", .verb), VocabWord("open", ms: "buka", .verb),
        VocabWord("watch", ms: "tonton", emoji: "📺", .verb), VocabWord("play", ms: "main", emoji: "▶️", .verb),
        VocabWord("next", ms: "seterusnya", emoji: "⏭️", .descriptor), VocabWord("back", ms: "kembali", emoji: "◀️", .descriptor),
        VocabWord("video", ms: "video", emoji: "🎬", .noun), VocabWord("music", ms: "muzik", emoji: "🎵", .noun),
        VocabWord("news", ms: "berita", emoji: "📰", .noun), VocabWord("game", ms: "permainan", emoji: "🎮", .noun),
        VocabWord("YouTube", emoji: "▶️", .noun), VocabWord("Google", emoji: "🔎", .noun),
        VocabWord("link", ms: "pautan", emoji: "🔗", .noun), VocabWord("page", ms: "halaman", emoji: "📄", .noun),
        VocabWord("share", ms: "kongsi", emoji: "📤", .verb), VocabWord("download", ms: "muat turun", emoji: "⬇️", .verb),
        VocabWord("www.", .noun), VocabWord(".com", .noun),
        VocabWord("how to", ms: "bagaimana", .question), VocabWord("what is", ms: "apa itu", .question),
        VocabWord("computer", ms: "komputer", emoji: "💻", .noun),
        VocabWord("answer", ms: "jawapan", .noun), VocabWord("question", ms: "soalan", emoji: "❓", .noun),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("name", ms: "nama", .noun), VocabWord("day", ms: "hari", .noun),
        VocabWord("thing", ms: "benda", .noun), VocabWord("joke", ms: "jenaka", emoji: "😄", .noun),
        VocabWord("weather", ms: "cuaca", emoji: "🌤️", .noun), VocabWord("birthday", ms: "hari jadi", emoji: "🎂", .noun),
        VocabWord("photo", ms: "gambar", emoji: "📷", .noun),
    ]),
    Category(en: "Chat", ms: "Sembang", words: [
        VocabWord("hello", ms: "hai", emoji: "👋", .social), VocabWord("bye", emoji: "👋", .social),
        VocabWord("please", ms: "tolong", emoji: "🙏", .social), VocabWord("thank you", ms: "terima kasih", emoji: "🙏", .social),
        VocabWord("sorry", ms: "maaf", .social), VocabWord("how are you", ms: "apa khabar", .social),
        VocabWord("I'm good", ms: "khabar baik", .social), VocabWord("wait a moment", ms: "tunggu sekejap", emoji: "⏳", .social),
        VocabWord("nice to meet you", ms: "selamat berkenalan", .social), VocabWord("see you later", ms: "jumpa lagi", .social),
        VocabWord("I use this to talk", ms: "Saya guna ini untuk bercakap", emoji: "💬", .social),
        VocabWord("good morning", ms: "selamat pagi", emoji: "🌅", .social),
        VocabWord("good night", ms: "selamat malam", emoji: "🌙", .social),
        // The talking verbs live with the talking, which is both where
        // they belong and what keeps Actions inside one page. Actions had
        // grown to 44 words on a board that shows 35, and the nine over
        // the line would have vanished without a gap or a crash — the
        // failure mode that cost us the `be` key for a whole build.
        VocabWord("say", ms: "kata", .verb), VocabWord("speak", ms: "cakap", .verb),
        VocabWord("tell", ms: "beritahu", .verb), VocabWord("ask", ms: "tanya", .verb),
        VocabWord("hear", ms: "dengar", .verb), VocabWord("talk", ms: "bercakap", emoji: "💬", .verb),
        VocabWord("explain", ms: "terangkan", .verb), VocabWord("send", ms: "hantar", emoji: "📤", .verb),
        VocabWord("show", ms: "tunjuk", .verb),
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
    Category(en: "Little words", ms: "Kata kecil", words: [
        VocabWord("to", ms: "ke", .function), VocabWord("for", ms: "untuk", .function),
        VocabWord("with", ms: "dengan", .function), VocabWord("in", ms: "dalam", .function),
        VocabWord("on", ms: "atas", .function), VocabWord("at", ms: "di", .function),
        VocabWord("of", ms: "daripada", .function), VocabWord("from", ms: "dari", .function),
        VocabWord("out", ms: "keluar", .function), VocabWord("up", ms: "naik", .function),
        VocabWord("and", ms: "dan", .function), VocabWord("but", ms: "tetapi", .function),
        VocabWord("or", ms: "atau", .function), VocabWord("because", ms: "kerana", .function),
        VocabWord("a", .function), VocabWord("the", .function),
        VocabWord("my", ms: "saya", .pronoun), VocabWord("me", ms: "saya", .pronoun),
        VocabWord("we", ms: "kami", .pronoun), VocabWord("they", ms: "mereka", .pronoun),
        VocabWord("again", ms: "lagi", emoji: "🔁", .descriptor),
        // `about` was the most frequently spelled word in the whole
        // tap-cost corpus — "a story about a monster", "videos about
        // space" — and it was in no category at all. `how` completes the
        // question words; it is here rather than in Core because Core has
        // exactly one free cell and `today` earned it. Malay unverified.
        VocabWord("about", ms: "tentang", .function),
        VocabWord("how", ms: "bagaimana", .question),
        // Measured against 200 sentences: every word below was being
        // spelled a letter at a time. Malay unverified.
        VocabWord("much", ms: "banyak", .descriptor), VocabWord("some", ms: "sedikit", .function),
        VocabWord("too", ms: "terlalu", .descriptor), VocabWord("long", ms: "lama", .descriptor),
        // Third measured pass, 200 sentences. Malay unverified.
        VocabWord("many", ms: "berapa banyak", .descriptor), VocabWord("a lot", ms: "banyak", .descriptor),
        VocabWord("yet", ms: "lagi", .descriptor), VocabWord("one", ms: "satu", .descriptor),
        VocabWord("so", ms: "sangat", .descriptor), VocabWord("until", ms: "sehingga", .function),
        VocabWord("your", ms: "awak punya", .pronoun),
    ]),
]

/// Lookup by either language's text, so Recents keeps color and emoji
/// regardless of which language a word was used in.
let vocabIndex: [String: VocabWord] = {
    var index: [String: VocabWord] = [:]
    for category in vocabulary {
        for word in category.words {
            if index[word.en] == nil { index[word.en] = word }
            if index[word.ms] == nil { index[word.ms] = word }
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
            nouns.insert(word.en.lowercased())
            nouns.insert(word.ms.lowercased())
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
            spelling[word.en.lowercased()] = word.en
            if spelling[word.ms.lowercased()] == nil { spelling[word.ms.lowercased()] = word.ms }
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
            described.insert(word.en.lowercased())
            described.insert(word.ms.lowercased())
        }
    }
    return described
}()

/// The places you can go to, which is the one case where the missing
/// preposition is never in doubt: "I go park" means "go TO THE park".
let placeWords: Set<String> = {
    guard let places = vocabulary.first(where: { $0.en == "Places" }) else { return [] }
    return Set(places.words.filter { $0.wordClass == .noun }.map { $0.en.lowercased() })
}()

/// Seed bigrams per language so prediction is useful before any learning.
let seedBigrams: [Lang: [String: [String]]] = [
    .en: [
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
    ],
    .ms: [
        "": ["Saya", "awak", "hai"],
        "saya": ["mahu", "suka", "boleh"],
        "awak": ["boleh", "mahu", "okay"],
        "mahu": ["makan", "lagi", "itu"],
        "suka": ["ini", "itu"],
        "boleh": ["tolong", "pergi"],
        "pergi": ["rumah", "sekolah", "sekarang"],
        "tolong": ["saya"],
        "makan": ["nasi", "ayam", "sekarang"],
        "minum": ["air", "jus", "teh"],
        "lukis": ["raksasa", "gambar"],
        "terima": ["kasih"],
        "apa": ["khabar"],
        "tidak": ["mahu", "boleh"],
    ],
]

// MARK: - Controller

