import SwiftUI
import ReplayKit
import NaturalLanguage
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

@main
struct TypikeyApp: App {
    init() { Self.applyTestFixtureIfPresent() }

    var body: some Scene {
        WindowGroup {
            BoardHomeView()
        }
    }

    /// Lets a UI test put board pages in place before the keyboard reads
    /// them.
    ///
    /// The test runner is its own app and has no App Group entitlement, so
    /// it cannot write to the shared container at all — fixtures written
    /// from a test silently went nowhere, and a test asserting on a word
    /// that also exists in the vocabulary passed anyway, for the wrong
    /// reason. The app can write there, so the test asks it to.
    ///
    /// Runs only when the argument is present, which nothing but a test
    /// ever passes.
    private static func applyTestFixtureIfPresent() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestPages"),
              flag + 1 < arguments.count,
              let store = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey")
        else { return }
        let value = arguments[flag + 1]
        if value == "none" {
            store.removeObject(forKey: BoardLayout.pagesKey)
        } else {
            store.set(Data(value.utf8), forKey: BoardLayout.pagesKey)
        }
    }
}

/// Shared card chrome for the home screen: a rounded, softly shaded
/// surface on the system's secondary grouped background so it reads
/// correctly in both light and dark mode.
extension View {
    func homeCardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

/// App identity: the icon's 2x2 key-tile motif inline next to the name,
/// compact enough to sit at the top of the scroll view without pushing
/// the status card below the fold.
struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                KeyTileMotif()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Typikey")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("The big-word keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Label("Large targets, built for people with limited fine motor control.", systemImage: "hand.point.up.braille")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

/// The app icon's 2x2 rounded-tile grid, recreated inline with the exact
/// Fitzgerald colors the keyboard's word-class palette uses (see
/// `WordClass.color` in KeyboardViewController.swift): pronoun yellow,
/// verb green, descriptor blue, noun orange.
private struct KeyTileMotif: View {
    private let yellow = Color(red: 1.00, green: 0.92, blue: 0.55)
    private let green = Color(red: 0.72, green: 0.90, blue: 0.63)
    private let blue = Color(red: 0.65, green: 0.82, blue: 0.98)
    private let orange = Color(red: 1.00, green: 0.80, blue: 0.58)

    var body: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            GridRow {
                tile(yellow)
                tile(green)
            }
            GridRow {
                tile(blue)
                tile(orange)
            }
        }
    }

    private func tile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
    }
}
