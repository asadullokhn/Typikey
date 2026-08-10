import Foundation
import Vision

/// The screen-learning word pipeline, shared by the broadcast extension
/// (which feeds it live frames) and the container app (which runs it on a
/// synthetic image for the on-device self-test). Keeping it in one place
/// is what makes the OCR path verifiable without a live broadcast — the
/// only thing the extension adds on top is ReplayKit frame delivery.
enum ScreenWords {
    static let suiteName = "group.com.asadullokh.ch5.typikey"
    static let countsKey = "screenWords"
    static let stampKey = "screenWordsStamp"
    static let capsKey = "screenCaps"
    static let blockedKey = "autoAddBlocked"
    static let keyboardAccessKey = "keyboardHasFullAccess"

    /// Interface furniture. A screen is mostly chrome — navigation bars,
    /// buttons, settings labels — and none of it is anything anyone says.
    /// Left unchecked the reader learns "Keyboards" and "Settings" instead
    /// of the words in the actual conversation.
    static let chrome: Set<String> = [
        "settings", "general", "keyboard", "keyboards", "done", "cancel", "edit", "delete",
        "save", "back", "next", "previous", "close", "open", "send", "reply", "forward",
        "search", "share", "add", "new", "more", "options", "menu", "home", "notifications",
        "privacy", "security", "account", "profile", "display", "sounds", "battery",
        "storage", "version", "update", "install", "allow", "deny", "enable", "disable",
        "select", "copy", "paste", "undo", "redo", "wrote", "typed", "message", "messages",
        "today", "yesterday", "now", "sent", "delivered", "read", "unread", "online",
        "typing", "photo", "photos", "camera", "video", "audio", "file", "files", "download",
        "upload", "loading", "error", "warning", "continue", "skip", "start", "stop", "pause",
        "play", "sign", "login", "logout", "password", "email", "phone", "name", "address",
        "app", "apps", "screen", "page", "tab", "tabs", "window", "view", "list", "show",
        "hide", "sort", "filter", "help", "about", "terms", "contact", "support", "typikey",
    ]

    /// Function words carry no context signal — the keyboard's bigrams and
    /// seeds already cover them, and letting them dominate the store would
    /// drown the distinctive words this feature exists to surface.
    static let stopwords: Set<String> = [
        "the", "and", "you", "for", "that", "with", "this", "are", "was",
        "have", "but", "not", "all", "can", "will", "from", "they", "been",
        "were", "which", "their", "your", "there", "would", "about", "into",
        "more", "some", "them", "than", "then", "also", "when", "what",
        "how", "who", "why", "has", "had", "its", "our", "out", "get",
    ]

    /// Lowercased tokens of 3-24 characters containing at least one letter
    /// and no digits, apostrophes allowed inside a word, function words
    /// dropped.
    static func tokens(in line: String) -> [String] {
        var splitSet = CharacterSet.alphanumerics
        splitSet.insert(charactersIn: "'")
        return line.lowercased()
            .components(separatedBy: splitSet.inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { token in
                token.count >= 3 && token.count <= 24
                    && token.rangeOfCharacter(from: .letters) != nil
                    // Digit-substitution artifacts ("he11o", "0ffice") are a
                    // classic OCR corruption — real words with digits are
                    // rare enough that dropping them all is the safer trade.
                    && token.rangeOfCharacter(from: .decimalDigits) == nil
                    && !stopwords.contains(token)
            }
    }

    /// A configured recognizer: on-device, cheapest pass, whatever language
    /// is on screen. `.fast` matters under the extension's ~50 MB ceiling.
    static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        return request
    }

    /// Confidence floor: garbled low-confidence OCR is the top context
    /// polluter — a wrong word suggested later is worse than a missed one.
    static func words(from request: VNRecognizeTextRequest) -> Set<String> {
        harvest(from: request).words
    }

    /// Pulls only the words a person actually said, and separately notes
    /// which of them were capitalized mid-sentence — the signal that a word
    /// is somebody's name rather than ordinary vocabulary.
    ///
    /// Most of a screen is furniture: navigation bars, buttons, settings
    /// rows. Three filters keep it out, and they matter more than the OCR
    /// itself, because a board full of "Keyboards" and "Wrote" is worse
    /// than no learning at all.
    ///  - Edge bands: the top and bottom tenths hold the status bar, the
    ///    navigation bar and the tab bar. Nothing conversational lives there.
    ///  - Prose only: a line of four or more words is a sentence; one or two
    ///    words on their own line is a button label.
    ///  - A chrome vocabulary, dropped outright.
    static func harvest(from request: VNRecognizeTextRequest,
                        ignoringEdges: Bool = true) -> (words: Set<String>, names: Set<String>) {
        var words: Set<String> = []
        var names: Set<String> = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { continue }
            if ignoringEdges {
                let box = observation.boundingBox // normalized, origin bottom-left
                if box.maxY > 0.92 || box.minY < 0.08 { continue }
            }
            let raw = candidate.string
                .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            // A short line is a label, not a sentence — but it is also
            // where a chat puts the sender's name, which is the single most
            // valuable word on the screen. So short lines contribute their
            // capitalized words only, and nothing else.
            let isProse = raw.count >= 4

            for (index, rawToken) in raw.enumerated() {
                let token = rawToken.trimmingCharacters(
                    in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
                let lower = token.lowercased()
                guard isUsable(lower) else { continue }
                // In prose, an opening capital is just the sentence starting;
                // on a label line every word stands on its own.
                let looksLikeName = token.first?.isUppercase == true && (!isProse || index > 0)
                guard isProse || looksLikeName else { continue }
                words.insert(lower)
                if looksLikeName { names.insert(lower) }
            }
        }
        return (words, names)
    }

    /// Length, digits, stopwords and interface furniture.
    static func isUsable(_ token: String) -> Bool {
        token.count >= 3 && token.count <= 24
            && token.rangeOfCharacter(from: .letters) != nil
            && token.rangeOfCharacter(from: .decimalDigits) == nil
            && !stopwords.contains(token)
            && !chrome.contains(token)
    }

    /// Merges new appearances into the bounded shared store.
    static func merge(_ fresh: Set<String>, names: Set<String> = [], into suite: UserDefaults) {
        guard !fresh.isEmpty else { return }
        var counts = (suite.dictionary(forKey: countsKey) as? [String: Int]) ?? [:]
        for word in fresh {
            counts[word, default: 0] += 1
        }
        suite.set(WordCounts.trimmed(counts), forKey: countsKey)
        suite.set(Date().timeIntervalSince1970, forKey: stampKey)

        if !names.isEmpty {
            var seen = Set(suite.array(forKey: capsKey) as? [String] ?? [])
            seen.formUnion(names)
            suite.set(Array(seen.prefix(WordCounts.limit)), forKey: capsKey)
        }
    }
}
