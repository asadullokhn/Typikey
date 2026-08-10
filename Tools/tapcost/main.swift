import Foundation

// What a sentence costs, measured without a keyboard.
//
// Every tap is up to 30 seconds of Sayfullah's life, so the number of
// taps a sentence takes is the only score this project has. Measuring it
// through the UI test runner works — it found four real bugs the day it
// was written — but it costs a simulator boot, a keyboard install and
// minutes per run, which is why it was run about once a week.
//
// This runs the same arithmetic against BoardPlan directly, in about a
// second, so a change to the home list or the spare-cell rule can be
// measured before it is built rather than after it ships. It models the
// board, not the UI: what it cannot see is whether the key was reachable
// on a real screen. Keep the UI tests for that.
//
//   swift Tools/tapcost/run.sh            the corpus, with a summary
//   swift Tools/tapcost/run.sh --verbose  every sentence, word by word

// MARK: - The board, as a thing you tap

/// Where the user is. Which level you are on decides what a word costs,
/// and going home is itself a tap — a cost the old measurement missed
/// entirely, because it assumed every word was reachable from wherever
/// the last one left you.
enum Level: Equatable {
    case home
    case category(Int)
}

struct Keyboard {
    var plan: BoardPlan
    var level: Level = .home
    var text = ""
    var taps = 0
    var spelled: [String] = []

    private var categories: [Category] { vocabulary }

    /// The words visible right now — as they READ right now, which is not
    /// the same thing. A verb cell after "I" reads `am`, not `be`, so a
    /// measurement that matched on the base form counted `am`, `are`,
    /// `is`, `going` and `went` as words with no key anywhere and charged
    /// six taps each for keys already on the board.
    private func visibleWords() -> Set<String> {
        let words: [VocabWord]
        switch level {
        case .home:
            words = plan.reshaped(BoardPlan.homeWords, after: text)
        case .category(let i):
            guard i < categories.count else { return [] }
            words = plan.reshaped(categories[i].words, after: text)
        }
        return Set(words.map { plan.label(for: $0, after: text).text.lowercased() })
    }

    /// Which category page a word lives on, and what reaching it costs
    /// from where we are: Categories, the tile, then the word.
    private func categoryHolding(_ word: String) -> Int? {
        categories.firstIndex { category in
            category.words.contains { plan.label(for: $0, after: text).text.lowercased() == word }
        }
    }

    /// The cheapest way to say the next thing, and how many words of the
    /// sentence it got through.
    ///
    /// Longest match first, because several cells are whole phrases:
    /// "thank you" and "how are you" are one key each, and counting them
    /// as two and three words charged this measurement for taps nobody
    /// makes. A phrase cell is the cheapest thing on the board — three
    /// words for one tap — so a measurement blind to them is blind to the
    /// keyboard's best trick.
    mutating func say(_ remaining: [String]) -> (consumed: Int, trace: String) {
        for length in stride(from: min(4, remaining.count), through: 2, by: -1) {
            let phrase = remaining.prefix(length).joined(separator: " ")
            if visibleWords().contains(phrase.lowercased()) {
                return (length, charge(1, phrase, via: level == .home ? "home" : "page"))
            }
            if let index = categoryHolding(phrase.lowercased()) {
                let cost = (level == .home ? 0 : 1) + 2 + 1
                level = .category(index)
                return (length, charge(cost, phrase, via: "page \(categories[index].en)"))
            }
        }
        return (1, say(one: remaining[0]))
    }

    /// Four routes compete for a single word. The suggestion bar is one of
    /// them and wins often, which is the whole reason it is worth the
    /// strip of screen it occupies.
    private mutating func say(one word: String) -> String {
        let target = word.lowercased()

        // The suggestion bar: one tap from any level, no navigation, and
        // it leaves you exactly where you were.
        if plan.predictions(after: text).contains(where: { $0.lowercased() == target }) {
            return charge(1, word, via: "bar")
        }

        // A key on the board in front of him.
        if visibleWords().contains(target) {
            return charge(1, word, via: level == .home ? "home" : "page")
        }

        // Home, if that is where it lives — plus the tap to get there.
        let goHome = level == .home ? 0 : 1
        let homeVisible = Set(plan.reshaped(BoardPlan.homeWords, after: text)
            .map { plan.label(for: $0, after: text).text.lowercased() })
        if homeVisible.contains(target) {
            level = .home
            return charge(goHome + 1, word, via: "home")
        }

        // A category page: Categories is a key on home, so this is the
        // trip home plus the tile plus the word.
        if let index = categoryHolding(target) {
            let cost = goHome + 2 + 1
            level = .category(index)
            return charge(cost, word, via: "page \(categories[index].en)")
        }

        // Nowhere. abc, one key per letter, then back home.
        spelled.append(word)
        let cost = goHome + 1 + word.count + 1
        level = .home
        return charge(cost, word, via: "spelled")
    }

    private mutating func charge(_ cost: Int, _ word: String, via route: String) -> String {
        taps += cost
        if !text.isEmpty, !text.hasSuffix(" ") { text += " " }
        text += word
        return "\(word) \(cost)  \(route)"
    }
}

// MARK: - The corpus

/// Things this particular person would actually send. Chosen to spread
/// across who he is writing to, because the vocabulary of asking ChatGPT
/// for something has almost nothing in common with the vocabulary of
/// telling his mother he is hungry.
let corpus: [(who: String, text: String)] = [
    // ChatGPT
    ("ChatGPT", "can you write a story about a monster"),
    ("ChatGPT", "please help me with my homework"),
    ("ChatGPT", "what is a good name for my comic"),
    ("ChatGPT", "can you make the story funny"),
    ("ChatGPT", "how do I draw a dragon"),
    ("ChatGPT", "write a song about the rain"),
    ("ChatGPT", "search for videos about space"),
    // Mum
    ("Mum", "I want to eat rice now"),
    ("Mum", "I am hungry"),
    ("Mum", "can I have juice please"),
    ("Mum", "I am tired I want to go home"),
    ("Mum", "what time is dinner"),
    ("Mum", "I finished my homework"),
    ("Mum", "I do not want to go to school"),
    ("Mum", "can we go to the park tomorrow"),
    // Dad
    ("Dad", "can you help me with the computer"),
    ("Dad", "I want to watch a video with you"),
    ("Dad", "when are you coming home"),
    // A friend
    ("a friend", "yesterday I went to the park with my friend"),
    ("a friend", "I am going to watch a video"),
    ("a friend", "do you want to play a game"),
    ("a friend", "that is very funny"),
    ("a friend", "I drew a new picture do you want to see it"),
    ("a friend", "see you at school tomorrow"),
    // Teacher / doctor
    ("teacher", "I do not understand the homework"),
    ("teacher", "can I go to the toilet please"),
    ("doctor", "my head hurts"),
    ("doctor", "I feel sick today"),
    // Everyday
    ("everyone", "hello how are you"),
    ("everyone", "thank you for the help"),
]

// MARK: - Run

let verbose = CommandLine.arguments.contains("--verbose")
var totalTaps = 0
var totalLetters = 0
var allSpelled: [String: Int] = [:]
var lines: [String] = []

for entry in corpus {
    var keyboard = Keyboard(plan: BoardPlan())
    var trace: [String] = []
    var words = entry.text.split(separator: " ").map(String.init)
    while !words.isEmpty {
        let (consumed, line) = keyboard.say(words)
        trace.append(line)
        words.removeFirst(consumed)
    }
    totalTaps += keyboard.taps
    totalLetters += entry.text.count
    for word in keyboard.spelled { allSpelled[word.lowercased(), default: 0] += 1 }

    let spelledNote = keyboard.spelled.isEmpty ? "" : "   spelled: \(keyboard.spelled.joined(separator: ", "))"
    lines.append(String(format: "%4d  %-52@  (to %@)%@",
                        keyboard.taps, entry.text as NSString,
                        entry.who as NSString, spelledNote as NSString))
    if verbose { lines.append(trace.map { "        \($0)" }.joined(separator: "\n")) }
}

print("\nTaps per sentence\n")
print(lines.joined(separator: "\n"))

let words = corpus.reduce(0) { $0 + $1.text.split(separator: " ").count }
print("""

Totals
  \(corpus.count) sentences, \(words) words
  \(totalTaps) taps against \(totalLetters) typing every letter
  \(String(format: "%.2f", Double(totalTaps) / Double(words))) taps per word
  \(allSpelled.values.reduce(0, +)) words spelled letter by letter\
\(allSpelled.isEmpty ? "" : ":")
""")
for (word, count) in allSpelled.sorted(by: { ($0.value, $1.key) > ($1.value, $0.key) }) {
    print("    \(word)\(count > 1 ? " ×\(count)" : "")")
}
print("")
