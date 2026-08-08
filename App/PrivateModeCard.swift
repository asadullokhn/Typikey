import SwiftUI

/// The settings a person may want before a conversation: whether Typikey
/// remembers it, whether verb keys reshape themselves, and how big the
/// board is.
///
/// Kept on the home screen rather than buried in Diagnostics, because it is
/// something a person reaches for *before* a private conversation, not
/// something they troubleshoot afterwards. The copy says exactly what stops
/// and what does not, since a privacy control nobody understands is worse
/// than none at all.
struct PrivateModeCard: View {
    @State private var isOn = Preferences.privateMode
    @State private var grammarOn = Preferences.smartGrammar
    @State private var size = Preferences.keyboardSize

    private static let sizeNames = ["Small", "Medium", "Large"]
    private static let sizeRows = ["four rows of words", "five rows of words", "six rows of words"]

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
                Text("Large gives \(Self.sizeRows[size]) — enough for the whole core vocabulary, including the small words like for, with and my that turn labels into sentences. Smaller sizes leave more of the app visible and drop the last rows. Takes effect the next time the keyboard opens.")
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
