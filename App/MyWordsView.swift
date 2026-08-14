import SwiftUI

struct MyWordsNavCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("My Words & Phrases")
                    .font(.title3.weight(.semibold))
                Text("Add your own keys to the keyboard's Mine page")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .homeCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Screen learning: starts/stops the TypikeyBroadcast upload extension via
/// the system broadcast picker (the ONLY way iOS allows a broadcast to
/// start — there is no programmatic start, and the system shows its own
/// red recording indicator the whole time). While broadcasting, the
/// extension OCRs throttled frames on-device and merges words into the
/// app group's `screenWords`; the keyboard biases its suggestions toward
/// them. Nothing ever leaves the device.

struct MyWordsView: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard

    @State private var myWords: [String] = []
    @State private var captureCounts: [String: Int] = [:]
    @State private var screenWords: [String: Int] = [:]
    @State private var skippedScreenWords: Set<String> = []
    @State private var armedWord: String?
    /// How many cells the Mine page has, as last measured by the keyboard.
    /// nil until the keyboard has been opened at least once.
    @State private var boardSlots: Int?
    @State private var newWord = ""

    var body: some View {
        List {
            Section {
                Label("Words you type often, and names read from your screen, are added here on their own. Remove one and it stays gone.",
                      systemImage: "wand.and.stars")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("My words and phrases") {
                if myWords.isEmpty {
                    Text("Words you add appear here, and on the keyboard's Mine page.")
                        .foregroundStyle(.secondary)
                }
                // The Mine page holds a fixed number of cells, and words
                // past it stay in this list without appearing there. Said
                // plainly, with the number, because the alternative is a
                // word he added quietly never showing up.
                if let slots = boardSlots, myWords.count > slots {
                    Label("The Mine page fits \(slots) words. The \(myWords.count - slots) after that stay in this list and still show up in suggestions — remove a few to put them on the board.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("myWordsOverflowNotice")
                }
                ForEach(myWords, id: \.self) { word in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word)
                                .font(.title3)
                                .accessibilityIdentifier(word)
                            if let category = Self.autoCategory(for: word) {
                                Text("Also on the \(category) page")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            removeWord(word)
                        } label: {
                            Text(armedWord == word ? "Tap again" : "Remove")
                                .font(.headline)
                                .frame(minWidth: 130, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(armedWord == word ? .red : nil)
                    }
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Add a word or phrase…", text: $newWord)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("myWordsField")
                    Button {
                        addManualWord()
                    } label: {
                        Text("Add")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("myWordsAdd")
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("My Words")
        .onAppear(perform: reload)
    }

    private func reload() {
        myWords = freshMyWords()
        captureCounts = freshCaptureCounts()
        screenWords = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int]) ?? [:]
        skippedScreenWords = Set(store.array(forKey: "screenSkipped") as? [String] ?? [])
        boardSlots = KeyboardFit.read(from: store).map(\.slots).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Reads myWords straight from the shared suite — never from @State —
    /// so a caller about to mutate and write back never clobbers a write
    /// the keyboard extension made in between this screen's last reload
    /// and now.
    private func freshMyWords() -> [String] {
        (store.array(forKey: "myWords") as? [String]) ?? []
    }

    private func freshCaptureCounts() -> [String: Int] {
        (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
    }

    /// The keyboard files words with exactly this call, so what this screen
    /// says about a word is what the board actually does — the filing must
    /// be visible, never something to hunt for.
    static func autoCategory(for word: String) -> String? {
        WordFiling.category(for: word)
    }

    private func removeWord(_ word: String) {
        if armedWord == word {
            var words = freshMyWords()
            words.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
            store.set(words, forKey: "myWords")
            // Removing is the veto on automatic adding: without this the
            // word is simply re-added the next time it crosses the
            // threshold, and the user cannot win an argument with the app.
            var blocked = Set(store.array(forKey: ScreenWords.blockedKey) as? [String] ?? [])
            blocked.insert(word.lowercased())
            store.set(Array(blocked), forKey: ScreenWords.blockedKey)
            myWords = words
            armedWord = nil
        } else {
            armedWord = word
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if armedWord == word { armedWord = nil }
            }
        }
    }

    private func addManualWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var words = freshMyWords()
        guard !words.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            myWords = words
            newWord = ""
            return
        }
        words.append(trimmed)
        store.set(words, forKey: "myWords")
        myWords = words
        newWord = ""
    }
}

/// Live status of the on-device phrase-completion model, so the team can
/// see on any device whether chips will appear and how fast — the same
/// model and call the keyboard uses, run in the app process.
