import SwiftUI

/// Picking a keyboard size by looking at it.
///
/// It was a segmented control reading Small / Medium / Large, which asks
/// someone to guess what those mean and then go and find out. Sizes are a
/// visual thing, so they are shown: each option draws the screen with the
/// keyboard filling its real share of it, at the real proportion.
///
/// The row height under each one is the number that actually matters —
/// it is what you are aiming at — and the line underneath reports what the
/// keyboard last measured on this device, so a setting that did not take
/// effect says so instead of looking like it worked.
struct KeyboardSizePicker: View {
    @Binding var selection: Int
    /// What the keyboard last measured for itself. nil until it has run.
    let measured: KeyboardFit.Reading?

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(KeyboardSize.allCases) { size in
                    Button {
                        selection = size.rawValue
                    } label: {
                        SizeOption(size: size,
                                   phone: isPhone,
                                   selected: size.rawValue == selection)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(size.name), keyboard \(Int(size.height(phone: isPhone))) points tall")
                    .accessibilityAddTraits(size.rawValue == selection ? [.isSelected] : [])
                }
            }
            .accessibilityIdentifier("keyboardSizePicker")

            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("keyboardSizeStatus")
        }
    }

    /// Reports the measurement rather than the intention. If the keyboard
    /// is not the height that was chosen, that is the interesting fact and
    /// it belongs on screen — not discovered by squinting at the keyboard.
    private var statusLine: String {
        guard let measured, measured.granted > 0 else {
            return "The board is always four rows; the size changes how big each key is. Open the keyboard once and this will show what it measured."
        }
        let chosen = KeyboardSize.clamped(selection)
        let want = Int(chosen.height(phone: isPhone))
        let got = Int(measured.granted)
        if abs(got - want) <= 24 {
            return "The keyboard is \(got)pt tall — rows of about \(Int(measured.rowHeight))pt. That matches \(chosen.name)."
        }
        return "Chosen: \(chosen.name), \(want)pt. The keyboard last measured \(got)pt. Close the keyboard and reopen it; if it still disagrees, Allow Full Access is probably off, so the setting never reaches it."
    }
}

/// One option: a screen with the keyboard's real share of it filled in.
private struct SizeOption: View {
    let size: KeyboardSize
    let phone: Bool
    let selected: Bool

    /// A stand-in screen height to scale against. The point is the ratio
    /// between the three options, not a faithful model of any one device.
    private var screenHeight: CGFloat { phone ? 850 : 1180 }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let share = min(size.height(phone: phone) / screenHeight, 0.75)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(selected ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(height: max(geo.size.height * share, 6))
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
            .frame(height: 96)

            Text(size.name)
                .font(.subheadline.weight(selected ? .bold : .regular))
            Text("\(Int(size.rowHeight(phone: phone)))pt keys")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
