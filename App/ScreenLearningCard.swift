import SwiftUI
import ReplayKit
import Vision

struct ScreenLearningCard: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    @State private var learned: [(word: String, count: Int)] = []
    @State private var keyboardReady = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learn from my screen")
                        .font(.title3.weight(.semibold))
                    Text("Tap Start, then Start Broadcast")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                BroadcastPickerButton()
                    .frame(width: 130, height: 56)
            }

            Text("While it's on, Typikey reads the words on your screen and suggests them when you type — names, places, whatever you're replying to. Everything stays on this device; nothing is ever uploaded. iOS shows a red indicator the whole time, and you can stop from the same button or Control Center.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("A couple of minutes is usually enough — the words are kept for good. To start it without opening the app, add the Start screen learning shortcut to AssistiveTouch (Settings → Accessibility → Touch → AssistiveTouch → Customise Top Level Menu) so it can be reached with a pointer or joystick, or assign it to a switch under Switch Control.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !learned.isEmpty {
                Divider()
                Text("\(learned.count) words learned")
                    .font(.footnote.weight(.semibold))
                Text(learned.prefix(12).map(\.word).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("screenWordsSample")
                if !keyboardReady {
                    Label("The keyboard can't see these yet — turn on Allow Full Access in Settings.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Forget them", role: .destructive) {
                    store.removeObject(forKey: ScreenWords.countsKey)
                    store.removeObject(forKey: ScreenWords.stampKey)
                    refresh()
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .homeCardStyle()
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        let counts = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int]) ?? [:]
        learned = counts.sorted { $0.value > $1.value }.map { (word: $0.key, count: $0.value) }
        // The keyboard writes this flag whenever it runs WITH Full Access —
        // the only way the app can tell whether the grant is in place, since
        // without it the keyboard cannot reach this container at all.
        keyboardReady = store.bool(forKey: ScreenWords.keyboardAccessKey)
    }
}

/// Screen-learning troubleshooting, in the Diagnostics drawer rather than
/// on the card: each stage of the pipeline reports for itself, so a silent
/// failure names which link broke instead of just doing nothing. Daily use
/// never needs this; a bad session does.
struct ScreenReaderDiagnostics: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    @State private var learnedCount = 0
    @State private var sessionStarted = false
    @State private var framesSeen = false
    @State private var keyboardReady = false
    @State private var selfTest: String?
    @State private var fit: KeyboardFit.Reading?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Screen learning")
                .font(.headline)

            status("Broadcast started", ok: sessionStarted,
                   noText: "Not started yet — use the record button on the card above")
            status("Screen frames read", ok: framesSeen,
                   noText: sessionStarted ? "Started, but no frames arrived" : "Waiting for a broadcast")
            status("\(learnedCount) words learned", ok: learnedCount > 0, noText: "No words yet")
            status("Keyboard can read them", ok: keyboardReady,
                   noText: "Turn on Allow Full Access: Settings → General → Keyboard → Keyboards → Typikey")

            Divider()

            Text("Keyboard fit")
                .font(.headline)
            if let fit {
                status("Whole board visible", ok: fit.fits,
                       noText: "The bottom row is cut off by \(Int((fit.rowHeight * CGFloat(fit.rows) + fit.barHeight) - fit.granted))pt")
                Text("Asked iOS for \(Int(fit.requested))pt, got \(Int(fit.granted))pt — \(fit.rows) rows of \(Int(fit.rowHeight))pt."
                     + (fit.shortfall > 0 ? " iOS reserves a band above third-party keyboards; Typikey adds \(Int(fit.shortfall))pt to its request to compensate." : ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("keyboardFitDetail")
            } else {
                Text("Open the keyboard once and come back — only the keyboard can see the height iOS gives it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Test the reader") { runSelfTest() }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("screenSelfTest")
            if let selfTest {
                Text(selfTest)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("screenSelfTestResult")
            }
        }
        .onAppear(perform: refresh)
    }

    private func status(_ label: String, ok: Bool, noText: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.footnote.weight(.medium))
                if !ok {
                    Text(noText).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func refresh() {
        learnedCount = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int])?.count ?? 0
        sessionStarted = store.double(forKey: "screenSessionStart") > 0
        framesSeen = store.double(forKey: "screenLastFrame") > 0
        keyboardReady = store.bool(forKey: ScreenWords.keyboardAccessKey)
        fit = KeyboardFit.read(from: store)
    }

    /// Runs the exact OCR path the broadcast extension uses — same request,
    /// same tokenizer — against a rendered image, so the reader can be
    /// proven on this device without starting a broadcast.
    private func runSelfTest() {
        let sample = "Ratna is bringing pizza to Singapore on Friday"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 56), .foregroundColor: UIColor.black,
        ]
        // Size the canvas to the text: a fixed width would clip the tail of
        // the sentence, and a clipped word looks exactly like an OCR miss.
        let textSize = (sample as NSString).size(withAttributes: attributes)
        let size = CGSize(width: ceil(textSize.width) + 80, height: ceil(textSize.height) + 80)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (sample as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
        }
        guard let cgImage = image.cgImage else {
            selfTest = "Could not render the test image."
            return
        }
        let request = ScreenWords.makeRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            selfTest = "Reader failed: \(error.localizedDescription)"
            return
        }
        let words = ScreenWords.words(from: request).sorted()
        selfTest = words.isEmpty
            ? "Reader found no words — the OCR step is not working on this device."
            : "Reader works. From a test image it read: \(words.joined(separator: ", "))"
    }
}

/// The system broadcast picker, wearing our own button.
///
/// `RPSystemBroadcastPickerView` draws its own icon, which renders as an
/// invisible blank on iPadOS 26 — leaving the card with a hole where the
/// only actionable control should be. So the picker itself is kept in the
/// hierarchy (iOS allows no other way to start a broadcast) but hidden
/// behind a proper button, whose tap is forwarded to the picker's internal
/// button. If that internal button can't be found, the picker is shown as
/// it is rather than leaving the user with nothing to press.
private struct BroadcastPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = "com.asadullokh.ch5.typikey.broadcast"
        picker.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(picker)

        BroadcastLauncher.shared.picker = picker
        let systemButton = BroadcastLauncher.firstButton(in: picker)
        picker.isHidden = systemButton != nil

        var config = UIButton.Configuration.filled()
        config.title = "Start"
        config.image = UIImage(systemName: "record.circle")
        config.imagePadding = 6
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = systemButton == nil
        button.addAction(UIAction { _ in
            BroadcastLauncher.shared.presentSheet()
        }, for: .touchUpInside)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.widthAnchor.constraint(equalToConstant: 60),
            picker.heightAnchor.constraint(equalToConstant: 60),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Tremor-friendly "My Words" editor (Gilbert build, task G2). Reads and
/// writes the same shared-suite keys the keyboard extension owns
/// (`myWords`, `captureCounts` — see Task G1): the app always has access
/// to the app group, unlike the keyboard, which gates on Full Access.
/// The keyboard picks up edits here on its next `viewWillAppear`.
