import Foundation
import Security

/// The app's side of an API-backed board.
///
/// Everything here runs in the container app and nowhere else. The keyboard
/// cannot reach this code, cannot read the key, and makes no requests —
/// invariant 5 is enforced by where the file lives, not by a promise. What
/// crosses to the keyboard is a `PredictionTable`: a dictionary of words and
/// finished sentences it looks up offline.
///
/// **What leaves the device, exactly.** The contexts asked about, and
/// nothing else: single vocabulary words (`want`, `go`, `what`) and pairs of
/// vocabulary words he has actually used together (`want|to`). Never a
/// sentence he wrote, never a message he received, never a screen-learned
/// word — those are the ones that carry names, and a name is the single most
/// identifying thing this app ever holds. The filter is applied before the
/// request is built, in `contexts()`, not by asking the model to be careful.
@MainActor
final class AIAssist: ObservableObject {
    enum Status: Equatable {
        case idle
        case working(done: Int, total: Int)
        case failed(String)
        case ready(continuations: Int, phrases: Int)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var table: PredictionTable?

    /// Off until somebody turns it on, and the switch lives in the app.
    /// A keyboard that started calling an API because of a default would be
    /// the worst possible version of this feature.
    var isEnabled: Bool {
        get { store.bool(forKey: PredictionTable.enabledKey) }
        set {
            store.set(newValue, forKey: PredictionTable.enabledKey)
            if !newValue { PredictionTable.clear(from: store); table = nil; status = .idle }
            objectWillChange.send()
        }
    }

    var hasKey: Bool { Keychain.read(Self.keyAccount) != nil }

    private static let keyAccount = "anthropic.apiKey"
    private static let model = "claude-sonnet-5"

    private let store: UserDefaults

    init(store: UserDefaults = UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard) {
        self.store = store
        table = PredictionTable.load(from: store)
        if let table { status = .ready(continuations: table.continuations.count,
                                       phrases: table.phrases.count) }
    }

    /// The key never goes in UserDefaults, and never in the shared
    /// container: the keyboard can read that container, and a key it can
    /// read is a key it could use. Keychain, app-only.
    func setKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed.isEmpty ? Keychain.delete(Self.keyAccount)
                        : Keychain.write(trimmed, account: Self.keyAccount)
        objectWillChange.send()
    }

    // MARK: Building a table

    func refresh() async {
        guard let key = Keychain.read(Self.keyAccount) else {
            status = .failed("No API key saved.")
            return
        }
        let batches = contexts().chunked(into: 25)
        guard !batches.isEmpty else {
            status = .failed("Nothing learned yet — type with Typikey first, then refresh.")
            return
        }

        var built = PredictionTable(source: Self.model, generated: Date())
        for (index, batch) in batches.enumerated() {
            status = .working(done: index, total: batches.count)
            do {
                let answer = try await ask(batch, key: key)
                for (context, reply) in answer {
                    let words = reply.words.filter { vocabIndex[$0] != nil || vocabIndex[$0.capitalized] != nil }
                    if !words.isEmpty { built.continuations[context] = Array(words.prefix(5)) }
                    if !reply.phrases.isEmpty { built.phrases[context] = Array(reply.phrases.prefix(3)) }
                }
            } catch {
                status = .failed(error.localizedDescription)
                return
            }
        }

        // Written only once the whole run succeeded. A half-built table is
        // a board that changed for no reason anyone can explain.
        built.save(to: store)
        table = built
        status = .ready(continuations: built.continuations.count, phrases: built.phrases.count)
    }

    /// What to ask about: the words he actually uses, and the pairs he
    /// actually types. Vocabulary only — see the note at the top of the file
    /// for why screen-learned words are excluded here rather than filtered
    /// later.
    private func contexts() -> [String] {
        let usage = (store.dictionary(forKey: "usage") as? [String: Int]) ?? [:]
        let bigrams = (store.dictionary(forKey: "bigrams") as? [String: Int]) ?? [:]

        var wanted: [String] = [""]
        wanted += usage
            .filter { vocabIndex[$0.key] != nil }
            .sorted { $0.value > $1.value }
            .prefix(40)
            .map { $0.key.lowercased() }
        wanted += bigrams
            .sorted { $0.value > $1.value }
            .prefix(40)
            .map { $0.key.replacingOccurrences(of: "|", with: " ").lowercased() }
            .filter { $0.split(separator: " ").allSatisfy { vocabIndex[String($0)] != nil } }

        // With nothing learned yet there is still something worth asking:
        // the words the board opens on are the ones every first sentence
        // starts from.
        if wanted.count == 1 {
            wanted += BoardPlan.homeSelection
                .filter { vocabIndex[$0] != nil }
                .map { $0.lowercased() }
        }
        return Array(Set(wanted)).sorted()
    }

    private struct Reply: Decodable {
        var words: [String] = []
        var phrases: [String] = []
    }

    private func ask(_ contexts: [String], key: String) async throws -> [String: Reply] {
        let listed = contexts
            .map { $0.isEmpty ? "\"\" (the start of a message)" : "\"\($0)\"" }
            .joined(separator: "\n")
        let prompt = """
        A person who cannot speak types short messages to family, friends, \
        teachers and carers on a communication board. Every tap is slow, so \
        the goal is to save taps.

        For each context below, give:
        - "words": up to 5 single words that most often come next
        - "phrases": up to 3 complete, natural messages that start with that \
        context, each one something a real person would send

        Contexts:
        \(listed)

        Reply with JSON only: an object whose keys are the contexts exactly \
        as written above (use "" for the start of a message) and whose values \
        are objects with "words" and "phrases" arrays. No other text.
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "max_tokens": 4000,
            "messages": [["role": "user", "content": prompt]],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AssistError.http(http.statusCode, String(decoding: data, as: UTF8.self).prefix(200).description)
        }
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = envelope["content"] as? [[String: Any]],
              let text = content.compactMap({ $0["text"] as? String }).first
        else { throw AssistError.malformed }

        // Models fence JSON often enough that stripping it is cheaper than
        // arguing with the prompt about it.
        let json = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = try? JSONDecoder().decode([String: Reply].self, from: Data(json.utf8))
        else { throw AssistError.malformed }
        return parsed
    }

    enum AssistError: LocalizedError {
        case http(Int, String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .http(let code, let body): return "The API returned \(code). \(body)"
            case .malformed: return "The reply was not in the shape we asked for."
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

/// Just enough Keychain for one secret.
enum Keychain {
    private static let service = "com.asadullokh.ch5.typikey"

    static func write(_ value: String, account: String) {
        delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, !data.isEmpty
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
