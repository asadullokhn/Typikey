import SwiftUI

/// The keyboard's memory against the ceiling it gets killed at.
///
/// The extension records its own high-water mark whenever it finishes
/// laying out a board; this reads it back. Being over the line does not
/// look like a crash to the person holding the iPad — the keyboard
/// disappears mid-sentence and the system one replaces it — so it is worth
/// a number somebody can look at rather than a rule everybody remembers.
struct FootprintCard: View {
    /// iOS gives a keyboard extension roughly 30–80MB depending on device
    /// and pressure. 50 is the number to design against: comfortably inside
    /// the worst case rather than close to the best one.
    private let budget = 50.0

    @State private var peak = 0.0
    @State private var measured: Date?

    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard memory")
                .font(.headline)

            if peak > 0 {
                Label {
                    Text("\(peak, specifier: "%.1f") MB at its highest")
                } icon: {
                    Image(systemName: peak < budget ? "checkmark.circle" : "exclamationmark.triangle")
                }
                .foregroundStyle(peak < budget ? Color.primary : Color.orange)

                ProgressView(value: min(peak / 80, 1))
                    .tint(peak < budget ? .green : .orange)

                Text("iOS kills a keyboard extension somewhere between 30 and 80 MB. "
                     + "Being killed looks like the keyboard vanishing mid-sentence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let measured {
                    Text("Measured \(measured.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Measure again") {
                    store.removeObject(forKey: Footprint.peakKey)
                    peak = 0
                }
            } else {
                Text("Type with Typikey once and the reading appears here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .homeCardStyle()
        .onAppear(perform: reload)
    }

    private func reload() {
        peak = store.double(forKey: Footprint.peakKey)
        let stamp = store.double(forKey: Footprint.stampKey)
        measured = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
}
