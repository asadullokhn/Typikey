import SwiftUI
import UIKit

/// The permissions, in one place, on the first run.
///
/// iOS gives a keyboard extension no way to ask for anything. There is no
/// prompt to present, no `requestAuthorization` to call: the keyboard is
/// added by hand in Settings, Full Access is a switch three levels deep,
/// and until both are done the app looks like it works and quietly does
/// nothing. Everything Fadillah sets — his words, private mode, the boards
/// she arranges — stays in the app. Nothing announces that.
///
/// So this is a checklist rather than a wizard. All of it is visible at
/// once, the steps can be done in any order, and each one reports its own
/// state instead of asking whether you did it. Nothing here blocks:
/// `Start typing` is always live, because a setup screen that traps
/// someone is worse than one they skipped.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Ticked by hand. The app cannot see which keyboards are installed —
    /// that list is outside its sandbox — so this step is the one thing
    /// here taken on trust. Step two proves it either way: Full Access
    /// cannot be granted to a keyboard that was never added.
    @AppStorage("onboardingKeyboardAdded") private var addedByHand = false

    @State private var fullAccess = false
    @State private var practiceText = ""

    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    step(1, "Add Typikey to your keyboards",
                         detail: "Settings → General → Keyboard → Keyboards → "
                               + "Add New Keyboard… → Typikey",
                         done: addedByHand || fullAccess) {
                        HStack(spacing: 12) {
                            openSettingsButton
                            if !fullAccess {
                                Button(addedByHand ? "Not yet" : "I've added it") {
                                    addedByHand.toggle()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }

                    step(2, "Allow Full Access",
                         detail: "Tap Typikey again in that same list and turn on Allow Full "
                               + "Access. It is what lets his own words, your boards and every "
                               + "setting in this app reach the keyboard. Typikey never sends "
                               + "anything to the internet — with the switch on or off.",
                         done: fullAccess) {
                        if fullAccess {
                            Label("Confirmed by the keyboard itself", systemImage: "checkmark.seal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            openSettingsButton
                        }
                    }

                    step(3, "Try it",
                         detail: "Tap the box, hold the globe key, and choose Typikey.",
                         done: !practiceText.isEmpty) {
                        PlainTextView(text: $practiceText,
                                      placeholder: "Type something here",
                                      minHeight: 80)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }

                    optional

                    Button {
                        dismiss()
                    } label: {
                        Text("Start typing")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
        // Both switches are flipped in Settings, so the answer changes
        // while this screen is in the background. Reading it on the way
        // back is the whole trick.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        fullAccess = store.bool(forKey: ScreenWords.keyboardAccessKey)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Two switches, once")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("iOS does not let a keyboard ask for permission, so both live in Settings. "
                 + "This page waits for them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var openSettingsButton: some View {
        Button("Open Settings") {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    /// Screen learning is genuinely optional and costs a broadcast to set
    /// up, so it is named here and done later rather than standing between
    /// anyone and a working keyboard.
    private var optional: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Screen learning is optional", systemImage: "eye")
                .font(.headline)
            Text("Typikey can read the words already on screen so replies are one tap instead of "
                 + "spelling. It runs on the device, keeps nothing but the words, and is switched "
                 + "on from Setup whenever you want it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .homeCardStyle()
    }

    private func step(_ number: Int, _ title: String, detail: String, done: Bool,
                      @ViewBuilder action: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                    .font(.system(size: 30))
                    .foregroundStyle(done ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            action()
        }
        .homeCardStyle()
    }
}
