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

    private static let sizeNames = ["Small", "Medium", "Large"]
    private static let sizeKeys = ["small keys", "medium keys", "the biggest keys"]

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

            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard size")
                    .font(.title3.weight(.semibold))
                Picker("Keyboard size", selection: $size) {
                    ForEach(0..<Self.sizeNames.count, id: \.self) { index in
                        Text(Self.sizeNames[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("keyboardSizePicker")
                .onChange(of: size) { _, newValue in
                    Preferences.keyboardSize = newValue
                }
                Text("The board is always four rows, exactly as designed — the size changes how big each key is, not how many there are. Large gives \(Self.sizeKeys[size]), which is what makes them easy to hit; smaller leaves more of the app you are typing in visible. Takes effect the next time the keyboard opens.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .homeCardStyle()
        .onAppear {
            isOn = Preferences.privateMode
            grammarOn = Preferences.smartGrammar
            size = Preferences.keyboardSize
        }
    }
}
