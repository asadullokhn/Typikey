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
            HomeView()
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

struct TryItCard: View {
    @Binding var practiceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it here")
                .font(.headline)
            PlainTextView(text: $practiceText,
                          placeholder: "Tap here, hold the globe key, choose Typikey")
        }
        .homeCardStyle()
    }
}

struct MyWordsNavCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("My Words & Phrases")
                    .font(.title3.weight(.semibold))
                Text("Add your own keys to the keyboard's Mine page")
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

/// Screen learning: starts/stops the TypikeyBroadcast upload extension via
/// the system broadcast picker (the ONLY way iOS allows a broadcast to
/// start — there is no programmatic start, and the system shows its own
/// red recording indicator the whole time). While broadcasting, the
/// extension OCRs throttled frames on-device and merges words into the
/// app group's `screenWords`; the keyboard biases its suggestions toward
/// them. Nothing ever leaves the device.
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
struct MyWordsView: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard

    @State private var myWords: [String] = []
    @State private var captureCounts: [String: Int] = [:]
    @State private var screenWords: [String: Int] = [:]
    @State private var skippedScreenWords: Set<String> = []
    @State private var armedWord: String?
    /// How many cells the Mine page has, as last measured by the keyboard.
    /// nil until the keyboard has been opened at least once.
    @State private var boardSlots: Int?
    @State private var newWord = ""

    var body: some View {
        List {
            Section {
                Label("Words you type often, and names read from your screen, are added here on their own. Remove one and it stays gone.",
                      systemImage: "wand.and.stars")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("My words and phrases") {
                if myWords.isEmpty {
                    Text("Words you add appear here, and on the keyboard's Mine page.")
                        .foregroundStyle(.secondary)
                }
                // The Mine page holds a fixed number of cells, and words
                // past it stay in this list without appearing there. Said
                // plainly, with the number, because the alternative is a
                // word he added quietly never showing up.
                if let slots = boardSlots, myWords.count > slots {
                    Label("The Mine page fits \(slots) words. The \(myWords.count - slots) after that stay in this list and still show up in suggestions — remove a few to put them on the board.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("myWordsOverflowNotice")
                }
                ForEach(myWords, id: \.self) { word in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word)
                                .font(.title3)
                                .accessibilityIdentifier(word)
                            if let category = Self.autoCategory(for: word) {
                                Text("Also on the \(category) page")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            removeWord(word)
                        } label: {
                            Text(armedWord == word ? "Tap again" : "Remove")
                                .font(.headline)
                                .frame(minWidth: 130, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(armedWord == word ? .red : nil)
                    }
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Add a word or phrase…", text: $newWord)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("myWordsField")
                    Button {
                        addManualWord()
                    } label: {
                        Text("Add")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("myWordsAdd")
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("My Words")
        .onAppear(perform: reload)
    }

    private func reload() {
        myWords = freshMyWords()
        captureCounts = freshCaptureCounts()
        screenWords = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int]) ?? [:]
        skippedScreenWords = Set(store.array(forKey: "screenSkipped") as? [String] ?? [])
        boardSlots = KeyboardFit.read(from: store).map(\.slots).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Reads myWords straight from the shared suite — never from @State —
    /// so a caller about to mutate and write back never clobbers a write
    /// the keyboard extension made in between this screen's last reload
    /// and now.
    private func freshMyWords() -> [String] {
        (store.array(forKey: "myWords") as? [String]) ?? []
    }

    private func freshCaptureCounts() -> [String: Int] {
        (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
    }

    /// The keyboard files words with exactly this call, so what this screen
    /// says about a word is what the board actually does — the filing must
    /// be visible, never something to hunt for.
    static func autoCategory(for word: String) -> String? {
        WordFiling.category(for: word)
    }

    private func removeWord(_ word: String) {
        if armedWord == word {
            var words = freshMyWords()
            words.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
            store.set(words, forKey: "myWords")
            // Removing is the veto on automatic adding: without this the
            // word is simply re-added the next time it crosses the
            // threshold, and the user cannot win an argument with the app.
            var blocked = Set(store.array(forKey: ScreenWords.blockedKey) as? [String] ?? [])
            blocked.insert(word.lowercased())
            store.set(Array(blocked), forKey: ScreenWords.blockedKey)
            myWords = words
            armedWord = nil
        } else {
            armedWord = word
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if armedWord == word { armedWord = nil }
            }
        }
    }

    private func addManualWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var words = freshMyWords()
        guard !words.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            myWords = words
            newWord = ""
            return
        }
        words.append(trimmed)
        store.set(words, forKey: "myWords")
        myWords = words
        newWord = ""
    }
}

/// Live status of the on-device phrase-completion model, so the team can
/// see on any device whether chips will appear and how fast — the same
/// model and call the keyboard uses, run in the app process.
struct EngineStatusSection: View {
    @State private var status = "Checking…"
    @State private var statusSymbol = "hourglass"
    @State private var probeResult: String?
    @State private var probing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phrase completion")
                .font(.headline)
            Label(status, systemImage: statusSymbol)
            if let probeResult {
                Label(probeResult, systemImage: "stopwatch")
            }
            Button(probing ? "Generating…" : "Test generation") { runProbe() }
                .disabled(probing || statusSymbol != "checkmark.circle")
        }
        .homeCardStyle()
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                status = "On-device model available"
                statusSymbol = "checkmark.circle"
            case .unavailable(let reason):
                status = "Model unavailable: \(String(describing: reason)). Check Settings → Apple Intelligence & Siri."
                statusSymbol = "exclamationmark.triangle"
            @unknown default:
                status = "Model availability unknown"
                statusSymbol = "questionmark.circle"
            }
        } else {
            status = "Needs iPadOS 26 — the keyboard falls back to word prediction"
            statusSymbol = "info.circle"
        }
#else
        status = "FoundationModels not in this SDK"
        statusSymbol = "info.circle"
#endif
    }

    private func runProbe() {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        probing = true
        probeResult = nil
        Task {
            let session = LanguageModelSession()
            do {
                let coldStart = Date()
                let cold = try await session.respond(
                    to: "Continue naturally with at most five words: I want to").content
                let coldMs = Int(Date().timeIntervalSince(coldStart) * 1000)
                let warmStart = Date()
                _ = try await session.respond(
                    to: "Continue naturally with at most five words: today we will").content
                let warmMs = Int(Date().timeIntervalSince(warmStart) * 1000)
                await MainActor.run {
                    probeResult = "cold \(coldMs) ms, warm \(warmMs) ms — \"\(cold.prefix(40))\""
                    probing = false
                }
            } catch {
                await MainActor.run {
                    probeResult = "Generation failed: \(String(describing: error))"
                    probing = false
                }
            }
        }
#endif
    }
}
