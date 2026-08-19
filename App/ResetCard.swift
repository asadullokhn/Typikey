import SwiftUI

/// The one action here that cannot be taken back.
///
/// Unlike the board's Clear key, this is a rare, deliberate act by whoever
/// is setting the device up rather than something done mid-sentence — so a
/// confirmation is the right guard here, and the wrong one there. What it
/// asks is not "are you sure" but "here is what you are about to lose",
/// because the honest answer depends entirely on that list.
struct ResetCard: View {
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reset Typikey", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .foregroundStyle(Color(uiColor: Palette.destructive))
            Text("Puts the keyboard back to the board it shipped with, and forgets everything it has learned.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(role: .destructive) { confirming = true } label: {
                Text("Reset everything")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(uiColor: Palette.destructive))
            .accessibilityIdentifier("resetEverything")

            if done {
                Text("Done. Typikey is back to how it shipped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resetConfirmation")
            }
        }
        .homeCardStyle()
        .alert("Reset everything?", isPresented: $confirming) {
            Button("Reset", role: .destructive) {
                FactoryReset.run()
                done = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the boards you arranged, your words and phrases, the words Typikey picked up from the screen, how often each word is used, and the switches above. It cannot be undone.")
        }
    }
}
