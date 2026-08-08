import UIKit

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

    var color: UIColor {
        switch self {
        case .pronoun:    return Palette.pronoun
        case .verb:       return Palette.verb
        case .descriptor: return Palette.descriptor
        case .noun:       return Palette.noun
        case .social:     return Palette.social
        case .question:   return Palette.question
        case .function:   return Palette.function
        case .punct:      return Palette.paper
        }
    }
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
        VocabWord("I", ms: "saya", .pronoun), VocabWord("you", ms: "awak", .pronoun),
        VocabWord("want", ms: "mahu", .verb), VocabWord("like", ms: "suka", .verb),
        VocabWord("go", ms: "pergi", .verb), VocabWord("help", ms: "tolong", emoji: "🤝", .verb),
        VocabWord("more", ms: "lagi", .descriptor), VocabWord("stop", ms: "berhenti", emoji: "✋", .verb),
        VocabWord("yes", ms: "ya", emoji: "✅", .social), VocabWord("no", ms: "tidak", emoji: "❌", .social),
        VocabWord("not", ms: "bukan", .descriptor), VocabWord("this", ms: "ini", .pronoun),
        VocabWord("that", ms: "itu", .pronoun), VocabWord("good", ms: "bagus", emoji: "👍", .descriptor),
        VocabWord("bad", ms: "teruk", emoji: "👎", .descriptor), VocabWord("now", ms: "sekarang", .descriptor),
        VocabWord("later", ms: "nanti", .descriptor), VocabWord("what", ms: "apa", .question),
        VocabWord("where", ms: "di mana", .question), VocabWord("when", ms: "bila", .question),
        VocabWord("who", ms: "siapa", .question), VocabWord("can", ms: "boleh", .verb),
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
        // The closed classes. These are the words that turn a board of
        // labels into sentences: "I am waiting" is a dead end without
        // "for", and no amount of prediction fixes that — a preposition has
        // to be in one known place, reachable in one tap, every time.
        // Core word lists (Banajee, Boenisch & Soto) put them among the
        // highest-frequency words in everything anyone says, and every
        // published core board carries them permanently.
        // Malay: unverified drafts, and weaker here than anywhere else.
        // Malay preposition boundaries do not line up with English ones,
        // possession is postposed ("kawan saya"), and Malay has no articles
        // at all — "a" and "the" have no Malay cell and are left in English
        // rather than invented. Needs Fadillah before it goes anywhere near
        // Sayfullah.
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
        VocabWord("again", ms: "lagi", .descriptor),
    ]),
    Category(en: "People", ms: "Orang", words: [
        VocabWord("I", ms: "saya", .pronoun), VocabWord("you", ms: "awak", .pronoun),
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
    ]),
    Category(en: "Feelings", ms: "Perasaan", words: [
        VocabWord("happy", ms: "gembira", emoji: "😊", .descriptor), VocabWord("sad", ms: "sedih", emoji: "😢", .descriptor),
        VocabWord("angry", ms: "marah", emoji: "😠", .descriptor), VocabWord("tired", ms: "penat", emoji: "😴", .descriptor),
        VocabWord("excited", ms: "teruja", emoji: "🤩", .descriptor), VocabWord("scared", ms: "takut", emoji: "😨", .descriptor),
        VocabWord("bored", ms: "bosan", emoji: "🥱", .descriptor), VocabWord("sick", ms: "sakit", emoji: "🤒", .descriptor),
        VocabWord("hungry", ms: "lapar", emoji: "😋", .descriptor), VocabWord("thirsty", ms: "haus", emoji: "🥵", .descriptor),
        VocabWord("okay", ms: "okay", emoji: "🙆", .descriptor), VocabWord("great", ms: "hebat", emoji: "🌟", .descriptor),
    ]),
    Category(en: "Food", ms: "Makanan", words: [
        VocabWord("water", ms: "air", emoji: "💧", .noun), VocabWord("rice", ms: "nasi", emoji: "🍚", .noun),
        VocabWord("chicken", ms: "ayam", emoji: "🍗", .noun), VocabWord("noodles", ms: "mi", emoji: "🍜", .noun),
        VocabWord("bread", ms: "roti", emoji: "🍞", .noun), VocabWord("fruit", ms: "buah", emoji: "🍎", .noun),
        VocabWord("banana", ms: "pisang", emoji: "🍌", .noun), VocabWord("juice", ms: "jus", emoji: "🧃", .noun),
        VocabWord("milk", ms: "susu", emoji: "🥛", .noun), VocabWord("tea", ms: "teh", emoji: "🍵", .noun),
        VocabWord("biryani", ms: "briyani", emoji: "🍛", .noun), VocabWord("chocolate", ms: "coklat", emoji: "🍫", .noun),
    ]),
    Category(en: "Places", ms: "Tempat", words: [
        VocabWord("home", ms: "rumah", emoji: "🏠", .noun), VocabWord("school", ms: "sekolah", emoji: "🏫", .noun),
        VocabWord("outside", ms: "luar", emoji: "🌳", .noun), VocabWord("shop", ms: "kedai", emoji: "🛒", .noun),
        VocabWord("park", ms: "taman", emoji: "🏞️", .noun), VocabWord("bus", ms: "bas", emoji: "🚌", .noun),
        VocabWord("MRT", emoji: "🚇", .noun), VocabWord("restaurant", ms: "restoran", emoji: "🍔", .noun),
        VocabWord("hospital", emoji: "🏥", .noun), VocabWord("toilet", ms: "tandas", emoji: "🚻", .noun),
        VocabWord("here", ms: "sini", .descriptor), VocabWord("there", ms: "sana", .descriptor),
    ]),
    Category(en: "Art", ms: "Seni", words: [
        VocabWord("draw", ms: "lukis", emoji: "🎨", .verb), VocabWord("paint", ms: "cat", emoji: "🖌️", .verb),
        VocabWord("color", ms: "warna", emoji: "🌈", .noun), VocabWord("picture", ms: "gambar", emoji: "🖼️", .noun),
        VocabWord("comic", ms: "komik", emoji: "📚", .noun), VocabWord("monster", ms: "raksasa", emoji: "👾", .noun),
        VocabWord("idea", emoji: "💡", .noun), VocabWord("cool", ms: "menarik", emoji: "😎", .descriptor),
        VocabWord("funny", ms: "kelakar", emoji: "😂", .descriptor), VocabWord("new", ms: "baru", emoji: "✨", .descriptor),
        VocabWord("finished", ms: "siap", emoji: "🏁", .descriptor), VocabWord("show you", ms: "tunjuk", emoji: "👀", .social),
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
    ]),
    Category(en: "Chat", ms: "Sembang", words: [
        VocabWord("hello", ms: "hai", emoji: "👋", .social), VocabWord("bye", emoji: "👋", .social),
        VocabWord("please", ms: "tolong", emoji: "🙏", .social), VocabWord("thank you", ms: "terima kasih", emoji: "🙏", .social),
        VocabWord("sorry", ms: "maaf", .social), VocabWord("how are you", ms: "apa khabar", .social),
        VocabWord("I'm good", ms: "khabar baik", .social), VocabWord("wait a moment", ms: "tunggu sekejap", emoji: "⏳", .social),
        VocabWord("nice to meet you", ms: "selamat berkenalan", .social), VocabWord("see you later", ms: "jumpa lagi", .social),
        VocabWord("I use this to talk", ms: "Saya guna ini untuk bercakap", emoji: "💬", .social),
        VocabWord("haha", emoji: "😂", .social),
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

