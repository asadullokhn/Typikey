import SwiftUI

/// Whether Typikey is actually working, answered before anything else on
/// the screen.
///
/// The app can only detect one thing about the keyboard, but it is the
/// thing that matters: whether the keyboard has ever run with Full Access.
/// Without that grant the keyboard cannot read the shared container at
/// all, so every setting on this screen — private mode, smart grammar,
/// keyboard size — stays in the app and the keyboard quietly keeps its
/// defaults. Nothing announces that. Somebody moves the size picker,
/// nothing happens, and the app looks broken.
///
/// So it is said here, in the first card, with the fix attached.
struct ReadinessCard: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    @State private var connected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(connected ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(connected ? "Typikey is ready" : "One step left")
                        .font(.title3.weight(.semibold))
                    Text(connected
                         ? "Your words and settings reach the keyboard."
                         : "The keyboard types fine, but it can't see anything you set here yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("readinessStatus")

            if !connected {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings → General → Keyboard → Keyboards → Typikey → **Allow Full Access**")
                        .font(.subheadline)
                    Text("Until that is on, your words, private mode, verb keys and keyboard size stay in this app — the keyboard keeps its own defaults and never sees them. Typing, prediction and learning all work either way.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .homeCardStyle()
        .onAppear { connected = store.bool(forKey: ScreenWords.keyboardAccessKey) }
    }
}
