import SwiftUI

/// Every setting in one place: whether Typikey remembers a conversation,
/// whether verb keys reshape themselves, and how big the board is.
///
/// All three cross from the app into the keyboard through the shared
/// container, so all three need Allow Full Access to have any effect —
/// which is what `ReadinessCard` says at the top of the screen, since a
/// setting that silently does nothing is worse than one that is missing.
///
/// Kept on the home screen rather than buried in Diagnostics, because it is
/// something a person reaches for *before* a private conversation, not
/// something they troubleshoot afterwards. The copy says exactly what stops
/// and what does not, since a privacy control nobody understands is worse
/// than none at all.
struct SettingsCard: View {
    @State private var isOn = Preferences.privateMode
    @State private var grammarOn = Preferences.smartGrammar
    @State private var size = Preferences.keyboardSize

    @State private var reshapeOn = Preferences.boardFollowsSentence
    @State private var fit: KeyboardFit.Reading?

    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private mode")
                        .font(.title3.weight(.semibold))
                    Text(isOn ? "Nothing is being remembered" : "Typikey is learning as you type")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("privateModeToggle")
            .onChange(of: isOn) { _, newValue in
                Preferences.privateMode = newValue
            }

            Text("The keyboard works exactly the same — every word, every suggestion it already knows. What stops is the remembering: no new words are learned, nothing is counted, no names are picked up, and nothing new reaches My Words. The keyboard turns purple so you can see at a glance that this is on.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $grammarOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verb keys follow the sentence")
                        .font(.title3.weight(.semibold))
                    Text(grammarOn ? "After “I am”, go reads going" : "Verb keys always read go, eat, watch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("smartGrammarToggle")
            .onChange(of: grammarOn) { _, newValue in
                Preferences.smartGrammar = newValue
            }

            Text("Keys never move — only the word on them changes. Every AAC app with this feature also lets you switch it off, because for some people the changing labels are more distracting than helpful. Turn it off and the keys stay in their plain form.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $reshapeOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use the spare keys")
                        .font(.title3.weight(.semibold))
                    Text(reshapeOn
                         ? "After “can you”, the I / you / he keys offer verbs"
                         : "Every key stays where it is, always")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("boardFollowsSentenceToggle")
            .onChange(of: reshapeOn) { _, newValue in
                Preferences.boardFollowsSentence = newValue
            }

            Text("Once you have written “can you”, nothing can follow it that reads “can you I” — so those seven cells are doing nothing, and they change to verbs instead. They turn green, so you can see which ones moved. Delete a word and they change straight back.\n\nThis is the one setting that moves a key. Fixed positions are the best-evidenced idea in this whole keyboard — one study measured 3.3 seconds per selection against keys that stay put, against 6.0 seconds for keys that move. If Sayfullah starts hunting, turn this off first.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard size")
                    .font(.title3.weight(.semibold))
                KeyboardSizePicker(selection: $size, measured: fit)
                    .onChange(of: size) { _, newValue in
                        Preferences.keyboardSize = newValue
                    }
            }

            Divider()

            PersonalizationCard()
        }
        .homeCardStyle()
        .onAppear {
            isOn = Preferences.privateMode
            grammarOn = Preferences.smartGrammar
            size = Preferences.keyboardSize
            reshapeOn = Preferences.boardFollowsSentence
            fit = KeyboardFit.read(from: store)
        }
    }
}

private struct PersonalizationCard: View {
    @StateObject private var service = PersonalizationService()

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calendar and Location are separate, optional sources. Typikey stores only bounded words, short titles, and a coarse place label — never coordinates, attendees, event bodies, or messages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Use upcoming event titles", isOn: Binding(
                    get: { service.calendarConsent },
                    set: { enabled in
                        Task { await service.setCalendarConsent(enabled) }
                    }))
                    .accessibilityIdentifier("calendarPersonalizationToggle")

                Toggle("Use current place label", isOn: Binding(
                    get: { service.locationConsent },
                    set: { enabled in
                        Task { await service.setLocationConsent(enabled) }
                    }))
                    .accessibilityIdentifier("locationPersonalizationToggle")

                Text(service.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let snapshot = service.snapshot, !snapshot.words.isEmpty {
                    Text("Published words")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(snapshot.words.prefix(8)), id: \.text) { word in
                        HStack {
                            Text(word.text)
                            Spacer()
                            Button("Block") {
                                Task { await service.block(word.text) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if let blocked = service.snapshot?.blockedWords, !blocked.isEmpty {
                    Text("Blocked")
                        .font(.subheadline.weight(.semibold))
                    ForEach(blocked.prefix(8), id: \.self) { word in
                        HStack {
                            Text(word)
                            Spacer()
                            Button("Allow") {
                                Task { await service.unblock(word) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    Button(service.isRegenerating ? "Updating…" : "Regenerate") {
                        Task { await service.regenerate() }
                    }
                    .disabled(service.isRegenerating)
                    .buttonStyle(.borderedProminent)

                    Button("Delete published data", role: .destructive) {
                        service.deletePublishedData()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Personalized suggestions", systemImage: "person.text.rectangle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .tint(.primary)
    }
}
