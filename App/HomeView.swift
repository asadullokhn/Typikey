import SwiftUI

/// The app's home screen.
///
/// It used to be one flat run of cards, every one the same weight: setup
/// steps you follow once sat above the things you open every day, and the
/// three settings were scattered between them. Nothing said what to look
/// at first.
///
/// Now it is grouped by what someone is actually here to do, in the order
/// they need it:
///
/// 1. **Is it working?** — answered before anything else, because when the
///    answer is no every setting below it silently does nothing.
/// 2. **Try it** — the practice field. Proof beats explanation.
/// 3. **Every day** — My Words, screen learning, the practice conversation.
/// 4. **Settings** — all three in one place instead of one card and a gap.
/// 5. **Help** — setup steps and how the keyboard behaves, collapsed,
///    because they are read once.
/// 6. **Diagnostics** — last, where troubleshooting belongs.
///
/// Sections are labelled so the screen can be scanned rather than read,
/// which matters for both readers here: Sayfullah drives a pointer at up
/// to 30 seconds a tap, and Fadillah is usually looking for one thing.
struct HomeView: View {
    @State private var practiceText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeroHeader()

                    ReadinessCard()

                    section("Try it") {
                        TryItCard(practiceText: $practiceText)
                    }

                    section("Every day") {
                        NavigationLink { PagesView() } label: { BoardsNavCard() }
                            .buttonStyle(.plain)
                        NavigationLink { MyWordsView() } label: { MyWordsNavCard() }
                            .buttonStyle(.plain)
                        ScreenLearningCard()
                        NavigationLink { ConversationDemoView() } label: { PracticeChatCard() }
                            .buttonStyle(.plain)
                    }

                    section("Settings") {
                        SettingsCard()
                    }

                    section("Help") {
                        SetupStepsCard()
                        HowItTypesCard()
                    }

                    section("Diagnostics") {
                        DiagnosticsCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        // Siri, Shortcuts and Back Tap land here: raise the broadcast sheet
        // so a training session is one confirming tap away. The short delay
        // lets the card's picker mount before it is asked to present.
        .onReceive(NotificationCenter.default.publisher(for: .startScreenLearning)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                BroadcastLauncher.shared.presentSheet()
            }
        }
    }

    /// A labelled group. The heading is what turns a scroll of identical
    /// cards into a page you can skim.
    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// One numbered instruction. Shared by every card that gives steps.
func setupStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(n)")
            .font(.headline)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Color.accentColor.opacity(0.15)))
        Text(text)
    }
}

/// A navigation card: icon, title, one line of what it is for, chevron.
/// Three of these existed as copies of the same HStack; now there is one.
struct NavCard: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
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

private struct BoardsNavCard: View {
    var body: some View {
        NavCard(symbol: "square.grid.2x2",
                title: "Boards",
                subtitle: "Arrange the category pages he sees, in the order he sees them.")
    }
}

private struct PracticeChatCard: View {
    var body: some View {
        NavCard(symbol: "bubble.left.and.text.bubble.right",
                title: "Practice conversation",
                subtitle: "See screen learning work on a pretend chat — nothing is recorded")
    }
}

/// The one-time steps, collapsed: they are read once and then never again,
/// so they should not sit above the things used daily.
private struct SetupStepsCard: View {
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    setupStep(1, "Open Settings")
                    setupStep(2, "General → Keyboard → Keyboards")
                    setupStep(3, "Add New Keyboard…")
                    setupStep(4, "Select Typikey")
                    setupStep(5, "Tap Typikey again and turn on Allow Full Access — this is what lets your own words and settings reach the keyboard")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use it")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    setupStep(1, "Open any app with a text field (Notes, Messages)")
                    setupStep(2, "Tap the text field, then hold the globe key")
                    setupStep(3, "Select Typikey")
                }
                // The strip of undo / copy / paste buttons above the
                // keyboard belongs to the app you are typing in, not to
                // Typikey — iOS gives a keyboard no way to remove it from
                // another app. Typikey hides it in its own practice field;
                // everywhere else it takes this one system switch.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hide the grey bar above the keyboard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    setupStep(1, "Settings → General → Keyboard")
                    setupStep(2, "Turn off Shortcuts")
                    Text("That strip of undo and paste buttons belongs to whichever app you are typing in, so no keyboard can remove it — this switch turns it off for every app at once, and gives Typikey back the height it was using.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Turn on Typikey", systemImage: "gearshape")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.primary)
        .homeCardStyle()
    }
}

private struct HowItTypesCard: View {
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Label("A word grid, like TouchChat: one tap inserts one whole word. Categories switch pages at the top.", systemImage: "square.grid.3x3")
                Label("Light keys write. Grey keys erase, and blue finishes the message.", systemImage: "circle.lefthalf.filled")
                Label("abc opens the letter keyboard — the fallback for words not in the grid, just like TouchChat's own.", systemImage: "keyboard")
                Label("Slide your finger across the keys — nothing happens until you lift. The key under your finger gets a blue ring.", systemImage: "hand.draw")
                Label("Accidental double-taps are ignored for half a second.", systemImage: "clock")
            }
            .padding(.top, 10)
        } label: {
            Label("How it types", systemImage: "questionmark.circle")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.primary)
        .homeCardStyle()
    }
}

private struct DiagnosticsCard: View {
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 18) {
                EngineStatusSection()
                ScreenReaderDiagnostics()
            }
            .padding(.top, 10)
        } label: {
            Label("Diagnostics", systemImage: "stethoscope")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.primary)
        .homeCardStyle()
    }
}
