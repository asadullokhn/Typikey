import UIKit
import NaturalLanguage

// MVP keyboard for limited fine motor control, modeled on the TouchChat
// interface the user already trusts: a color-coded word grid with category
// pages, where one tap inserts one whole word — the letter keyboard is only
// the fallback for words not in the grid (exactly TouchChat's own pattern).
//
// Access principles, each from the CH5 research:
// 1. Explore-then-commit: touching down costs nothing; sliding moves the
//    highlight; only lifting commits (VoiceOver keyboard pattern).
// 2. Double-tap guard: a repeat commit of the same key within 0.5s is
//    ignored (Game Accessibility Guidelines debounce recommendation).
// 3. No dead zones: every point of the surface belongs to a key, so
//    precision is never required — the nearest key wins.
// 4. Stable targets: prediction lives in the suggestion bar, and language
//    switching relabels cells in place — grid positions never move,
//    because motor planning depends on stable positions.
// Word-class colors follow the Fitzgerald key convention AAC systems use.

// MARK: - Language

final class KeyboardViewController: UIInputViewController {

    private enum KeyAction: Equatable {
        case word(String)
        case punct(String)
        case char(String)
        case shift
        case delete       // pinned: one character
        case deleteWord   // pinned
        case clearAll     // pinned, two-tap armed (Task 3)
        case cursorLeft   // pinned (Task 3)
        case cursorRight  // pinned (Task 3)
        case home         // pinned: back to the home board
        case toCategories
        case toWords(Int) // index into allCategories()
        case toLetters
        case toNumbers
        case space
        case ret
        case dismiss
        case language
    }

    private enum Level: Equatable {
        case home, categories, letters, numbers
        case words(Int) // index into allCategories()
    }

    private struct Key {
        let action: KeyAction
        let label: String
        let view: KeyView
        let row: Int
        let col: Int // 0...contentColumns+1
        let colSpan: Int
        let rowSpan: Int
    }

    // Three height presets, chosen in the app rather than on the board —
    // the size key spent a grid slot on something adjusted once and then
    // never again, and grid slots are the scarcest thing here.
    //
    // The iPad numbers are deliberately large. A dedicated AAC app takes
    // the whole screen, and this one has to fit a real core vocabulary:
    // Large is what makes six rows of ten possible at ~97pt each, which is
    // taller than a key on the system keyboard, not smaller.
    // Layout is fully width-responsive on top: when the system narrows us
    // (floating, Split View, Slide Over, Stage Manager) the grid drops to
    // compact mode instead of breaking. The phone numbers stay small
    // because an iPad preset would swallow an iPhone screen.
    private var sizePresets: [CGFloat] {
        UIDevice.current.userInterfaceIdiom == .phone ? [260, 310, 360] : [360, 500, 640]
    }
    private var sizeIndex = 2
    private var heightConstraint: NSLayoutConstraint?
    private var healAttempts = 0
    private var lastCompact = false
    private let topBarHeight: CGFloat = 56
    private let debounceInterval: TimeInterval = 0.5

    // The system can grant the extension's window LESS height than we
    // request (iPadOS 26 reserves an input-assistant band above
    // third-party keyboards). heightDeficit accumulates the measured
    // shortfall so the REQUEST compensates for it; requestedHeight is
    // what we ask the constraint for everywhere we used to ask for the
    // raw preset. Capped at 160 so it can never runaway. The whole request
    // is additionally clamped to 60% of the screen so a preset tuned for
    // portrait can never bury the app in iPhone landscape.
    private var heightDeficit: CGFloat = 0
    private var requestedHeight: CGFloat {
        let screenHeight = (view.window?.screen ?? UIScreen.main).bounds.height
        return min(sizePresets[sizeIndex] + heightDeficit, screenHeight * 0.6)
    }

    private var isCompact: Bool {
        view.bounds.width > 0 && view.bounds.width < 500
    }

    /// Top of the drawn keyboard band inside the container. Non-zero only
    /// when the system hands us an oversized container.
    fileprivate var layoutYOffset: CGFloat = 0

    /// Paints only the actual keyboard band — the rest of an oversized
    /// container stays transparent instead of a white wall.
    private let boardBackground = UIView()
    private var isRotating = false
    private var pendingHeightFix = false

    private var keys: [Key] = []
    private var contentRowCount = 4
    private var lastFitSignature: String?

    /// Private mode: typing works exactly as always, nothing is remembered.
    /// Re-read on every appearance so a toggle in the app takes effect on
    /// the very next field, not after a restart.
    private var isPrivate = false

    /// Whether verb keys follow the sentence. Every AAC product with this
    /// feature ships a way to turn it off; see `Preferences.smartGrammar`.
    private var smartGrammar = true

    /// The subject the sentence is about, when the last word named one.
    /// Only "be" needs it — it is the one English verb that still inflects
    /// for person as well as tense.
    private var verbSubject: String?

    /// The form verb cells are currently showing, recomputed whenever the
    /// text around the cursor changes. Held rather than derived on the fly
    /// so a rebuild is only triggered when the form actually changes.
    private var verbForm: Grammar.VerbForm = .base

    /// Inflected label -> the vocabulary word it came from, so a relabelled
    /// key keeps its color and emoji, and usage is counted against the base
    /// word rather than scattering across "go", "going" and "goes".
    private var inflectionBase: [String: String] = [:]
    private var level: Level = .home
    private var clearArmedAt: Date?
    private var lastIntentSignature: String?

    // Compact (floating / Split View / Slide Over): word boards drop to 5
    // wide-enough columns; the typing levels keep all 10 columns — a letter
    // that isn't there at all is worse than a narrower key. The pinned
    // column never moves: layoutKeys() sizes col 0 from bounds.width alone
    // (bounds.width / 11), never from contentColumns, so its frame is
    // identical whether the content grid is 5 or 10 columns wide.
    private var contentColumns: Int {
        switch level {
        case .letters, .numbers: return 10
        default: return isCompact ? 5 : 10
        }
    }

    private var isWordLevel: Bool {
        switch level {
        case .home, .categories, .words: return true
        case .letters, .numbers: return false
        }
    }
    private var shifted = false
    private var lang: Lang = .en
    private var lastCommit: (action: KeyAction, at: Date)?

    // Haptics are a no-op on iPads (no Taptic Engine) — wired anyway so an
    // iPhone build gets them for free. The input click is the audible
    // press feedback and needs no Full Access.
    private let haptics = Haptics()

    private let trackingView = TrackingView()
    private var suggestionButtons: [UIButton] = []
    private var globeButton: UIButton?
    private var highlightedIndex: Int?

    // Learned usage, persisted in the extension's own sandbox — no Full
    // Access, no shared containers, nothing leaves the keyboard.
    private var usageCounts: [String: Int] = [:]
    private var learnedBigrams: [String: Int] = [:]

    // The user's own words (Task G1 capture). Loaded in viewDidLoad and
    // reloaded in viewWillAppear so app-side edits in My Words appear the
    // next time the keyboard shows.
    private var myWords: [String] = []

    // Words recently OCR'd off the user's screen by the broadcast
    // extension (screen learning). Read-only here; reaches this process
    // through the app group, so it is empty without Full Access — and the
    // keyboard must work identically either way (invariant 5). Context
    // decays: a session older than 30 minutes stops influencing anything.
    private var screenWords: [String: Int] = [:]

    // Accumulates the current letters-level word as it's typed one key at
    // a time; cleared on any terminator (space/return/punctuation/delete/
    // level change/field switch) so only real letter-by-letter typing is
    // ever counted — grid-cell word taps never touch this.
    private var typedToken = ""

    /// Built-in vocabulary text, lowercased, for a case-insensitive
    /// "already known" check when deciding whether a typed token is a
    /// capture candidate.
    private static let knownVocabWords: Set<String> = Set(vocabIndex.keys.map { $0.lowercased() })

    /// Persistence home. With Full Access granted, learning and settings
    /// live in the app group so the container app can read and (later)
    /// edit them; without it, everything stays in the extension's own
    /// sandbox exactly as before — the keyboard never REQUIRES the grant.
    private lazy var store: UserDefaults = {
        guard hasFullAccess,
              let shared = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") else {
            return .standard
        }
        // One-time migration: adopt the sandbox learning the first time
        // the shared container becomes reachable, never overwriting data
        // that is already there.
        if shared.object(forKey: "usage") == nil,
           UserDefaults.standard.object(forKey: "usage") != nil {
            for key in ["usage", "bigrams", "lang", "sizeIndex"] {
                if let value = UserDefaults.standard.object(forKey: key) {
                    shared.set(value, forKey: key)
                }
            }
        }
        // Reaching this line proves Full Access is granted — the app has no
        // other way to know, so it reads this flag to tell the user whether
        // screen learning can actually reach the keyboard.
        shared.set(true, forKey: ScreenWords.keyboardAccessKey)
        return shared
    }()

    // Phrase completion (spec 2026-08-04). completionWords is the current
    // continuation; empty means none. Requests are issued only from the
    // trigger points (commit / textDidChange), never from inside
    // updateSuggestions — that would loop through onResult.
    private let completionEngine = CompletionEngine()
    private var completionWords: [String] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        haptics.prepare()
        view.backgroundColor = .clear

        usageCounts = (store.dictionary(forKey: "usage") as? [String: Int]) ?? [:]
        learnedBigrams = (store.dictionary(forKey: "bigrams") as? [String: Int]) ?? [:]
        myWords = (store.array(forKey: "myWords") as? [String]) ?? []
        autoFileCache = (store.dictionary(forKey: "wordFiling") as? [String: String]) ?? [:]
        reloadScreenWords()
        if let saved = store.string(forKey: "lang"), let restored = Lang(rawValue: saved) {
            lang = restored
        }
        sizeIndex = min(max(Preferences.keyboardSize(in: store), 0), sizePresets.count - 1)

        // Height lives on OUR content view, never on the root view. The
        // system derives the window height from content fitting; a height
        // constraint on the root view fights the system's cached window
        // frame, and the loser gets re-cached — that feedback loop is what
        // made the keyboard grow on every open/close cycle.
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.isMultipleTouchEnabled = false
        trackingView.controller = self
        view.addSubview(trackingView)
        let height = trackingView.heightAnchor.constraint(equalToConstant: sizePresets[sizeIndex])
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trackingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        heightConstraint = height

        boardBackground.backgroundColor = isPrivate ? Palette.privateBoard : Palette.board
        trackingView.addSubview(boardBackground)

        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        trackingView.addGestureRecognizer(hover)

        buildSuggestionBar()
        buildKeys()
    }

    // Pointer support (trackpad, Apple Pencil hover, AssistiveTouch
    // pointer devices): moves the same explore highlight touch does, but
    // never commits — lift/click still drives commit via touchLifted.
    @objc private func handleHover(_ g: UIHoverGestureRecognizer) {
        switch g.state {
        case .began, .changed:
            touchMoved(to: g.location(in: trackingView))
        case .ended, .cancelled, .failed:
            touchCancelled()
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload before buildKeys() below so app-side My Words edits and a
        // fresh field both show up on this appearance, and so a stale
        // in-progress token from a previous field never leaks into a new one.
        isPrivate = Preferences.privateMode(in: store)
        smartGrammar = Preferences.smartGrammar(in: store)
        // Size is chosen in the app now, so it has to be re-read here —
        // otherwise the change would not land until the extension is next
        // restarted, which from the user's side looks like nothing happened.
        sizeIndex = min(max(Preferences.keyboardSize(in: store), 0), sizePresets.count - 1)
        myWords = (store.array(forKey: "myWords") as? [String]) ?? []
        reloadScreenWords()
        promoteFrequentWords()
        typedToken = ""
        boardBackground.backgroundColor = isPrivate ? Palette.privateBoard : Palette.board
        heightConstraint?.constant = requestedHeight
        let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
        // Unconditional and unconditionally FIRST: reads and clears any
        // pending restore on every single appearance, on every instance,
        // whether or not this instance's own lastIntentSignature already
        // matches. A note must never outlive the one appearance it was
        // written for — see consumePendingRestore.
        let restored = consumePendingRestore(matching: signature)
        if signature != lastIntentSignature {
            lastIntentSignature = signature
            if let restored {
                level = restored
            } else {
                applyIntentLevel()
            }
        } else if let restored {
            level = restored // surviving instance after a ⌄ dismiss+retap: harmless reassert
        }
        buildKeys() // also refreshes the Go label for the new field
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rebuild when crossing the compact threshold — row chunking and
        // visible word count differ between wide and narrow layouts.
        if isCompact != lastCompact {
            lastCompact = isCompact
            buildKeys()
        }
        layoutKeys()

        // Self-heal: if the container is still oversized once rotation has
        // settled, rebuild the height constraint from scratch — reasserting
        // the existing one is not always enough to shrink the window.
        // Compares against requestedHeight (not the raw preset) so it
        // doesn't fight the undersize compensation below.
        let drift = trackingView.bounds.height - requestedHeight
        if !isRotating, !pendingHeightFix, drift > 1, healAttempts < 2, heightConstraint != nil {
            pendingHeightFix = true
            healAttempts += 1
            DispatchQueue.main.async { [weak self] in
                guard let self, let constraint = self.heightConstraint else { return }
                // A genuine value change — same-value updates are no-ops to
                // the layout engine and never shrink the stale window.
                constraint.constant = self.requestedHeight - 2
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                constraint.constant = self.requestedHeight
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.pendingHeightFix = false
            }
        }

        // Compensate: the system can hand the extension LESS height than
        // trackingView requests (iPadOS 26 reserves an input-assistant
        // band above third-party keyboards). Measure the shortfall
        // against the real container and bump the request by exactly
        // that much — guarded to escalate only when a NEW, larger
        // deficit is measured, so this can never compound into the
        // historic growth-loop bug documented at the top of this file.
        // The 160pt cap is applied BEFORE the comparison (not just to
        // the stored value) — otherwise, once heightDeficit is capped,
        // a stale/lagging view.bounds.height keeps reporting a raw
        // deficit above the (now-static) capped value forever, and this
        // block re-fires — and calls setNeedsLayout() — every single
        // layout pass indefinitely.
        // !isCompact: floating keyboard / Split View / Slide Over grants
        // are small BY DESIGN — that is not the input-assistant-band
        // shortfall this mechanism exists to compensate for. heightDeficit
        // never decays on its own, so measuring a compact-mode grant here
        // would let a float episode pin the deficit at the 160pt cap and
        // then inflate the docked, full-width keyboard afterward.
        // Pad-only: the reserved band this compensates for is an iPadOS 26
        // behavior. On a phone the only wide layout is landscape, where a
        // grant below the (screen-clamped) request is normal — learning it
        // as a deficit would leak extra height back into portrait.
        if !isRotating, !isCompact, UIDevice.current.userInterfaceIdiom == .pad,
           let constraint = heightConstraint, view.bounds.height > 0,
           view.bounds.height < constraint.constant - 1 {
            let deficit = min(constraint.constant - view.bounds.height, 160)
            if deficit > heightDeficit {
                heightDeficit = deficit
                constraint.constant = requestedHeight
                view.setNeedsLayout()
            }
        }
    }

    // On rotation the system can hand the extension transient, oversized
    // bounds. Reassert our height across the transition so the keyboard
    // settles back to its preset instead of staying huge.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        isRotating = true
        healAttempts = 0
        coordinator.animate(alongsideTransition: { _ in
            self.heightConstraint?.constant = self.requestedHeight
            self.view.setNeedsLayout()
        }, completion: { _ in
            self.heightConstraint?.constant = self.requestedHeight
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.isRotating = false
            self.view.setNeedsLayout()
        })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // An external context refresh (e.g. first responder moving to a
        // different field without this instance's viewWillAppear firing)
        // can bridge a half-typed token across fields. Reset rather than
        // count — the same reset-don't-count policy as every other
        // ambiguous path below.
        typedToken = ""
        refreshVerbForms()
        updateSuggestions()
        requestPhraseCompletion()
    }

    /// Rebuilds only when the board would actually read differently — a
    /// rebuild on every keystroke would fight the explore-then-commit
    /// slide, since rebuilding drops the highlight. `buildKeys` recomputes
    /// everything itself, so this only decides whether to call it.
    ///
    /// The subject is checked as well as the form, and that is not
    /// redundant: tapping "you" after "I" leaves the form at `.base` while
    /// changing what `be` should read from "am" to "are". Comparing the
    /// form alone is why the board looked frozen.
    private func refreshVerbForms() {
        guard lang == .en, smartGrammar, isWordLevel else { return }
        let context = contextBefore()
        guard Grammar.verbForm(after: context) != verbForm
                || Grammar.subject(before: context) != verbSubject else { return }
        buildKeys()
    }

    // MARK: Categories

    /// Tab 0 is Recents — computed from usage across both languages.
    ///
    /// His own words count here too. They used to fall out: Recents looked
    /// every used word up in `vocabIndex`, which only knows the built-in
    /// vocabulary, so a name he added and then used every day could never
    /// reach the one board that exists to shorten the reach to what he
    /// actually says.
    private func allCategories() -> [(name: String, words: [VocabWord])] {
        let recents = usageCounts
            .sorted { $0.value > $1.value }
            .compactMap { vocabIndex[$0.key] ?? myWord(named: $0.key) }
        var seen = Set<String>()
        var unique: [VocabWord] = []
        for word in recents where !seen.contains(word.en) {
            seen.insert(word.en)
            unique.append(word)
            if unique.count == wordSlots { break }
        }
        let recentsName = lang == .ms ? "Terkini" : "Recents"
        // Mine appends after the built-in categories — never reorders them
        // (invariant 1). Plain-text cells built on the fly; myWords are
        // never added to vocabIndex (that stays the built-in lookup only).
        let mineWords = myWords.map { VocabWord($0, .social) }
        // Auto-filing (Gilbert: the board should quietly configure itself,
        // but visibly, so nobody hunts for a word): a user's word that is
        // recognizably a person, place, or action ALSO appears at the end
        // of that category's page (invariant 1: new words go at the end),
        // in Mine's pink so it always reads as "his word". Everything
        // still lives in Mine regardless; ambiguous words stay Mine-only.
        var builtIn = vocabulary.map { (name: $0.name(lang), en: $0.en, words: $0.words) }
        for word in myWords {
            guard let target = autoCategory(for: word),
                  let i = builtIn.firstIndex(where: { $0.en == target }),
                  !builtIn[i].words.contains(where: { $0.en.caseInsensitiveCompare(word) == .orderedSame })
            else { continue }
            builtIn[i].words.append(VocabWord(word, .social))
        }
        return [(recentsName, unique)] + builtIn.map { ($0.name, $0.words) } + [("Mine", mineWords)]
    }

    /// A word of the user's own, as a cell. Matched case-insensitively
    /// because usage is counted on the text that was inserted and My Words
    /// stores names capitalised.
    private func myWord(named word: String) -> VocabWord? {
        myWords.first { $0.caseInsensitiveCompare(word) == .orderedSame }
            .map { VocabWord($0, .social) }
    }

    /// On-device semantic filing for a user's word: personal names go to
    /// People, place names to Places, verbs to Actions. Single words only —
    /// phrases stay Mine-only.
    ///
    /// Remembered in the store, not just in memory. `WordFiling` runs a
    /// tagger over three carrier sentences per word, and this cache used to
    /// die with the keyboard instance — so every fresh keyboard paid that
    /// cost again, for every word he has ever added, inside a process with
    /// a 60-80MB ceiling and a board that rebuilds whenever the verb form
    /// changes. Words only accumulate, so that bill only grows. A word's
    /// reading never changes; it is worth writing down.
    ///
    /// Empty string means "filed nowhere" — a plist cannot hold nil, and
    /// the distinction between "no category" and "not looked at yet" is the
    /// whole point of the cache.
    private var autoFileCache: [String: String] = [:]

    private func autoCategory(for word: String) -> String? {
        if let cached = autoFileCache[word] { return cached.isEmpty ? nil : cached }
        let result = WordFiling.category(for: word)
        autoFileCache[word] = result ?? ""
        learn(autoFileCache, forKey: "wordFiling")
        return result
    }

    // MARK: Frame (spec: the pinned column is identical on every level)

    /// The one pinned column, from the team's design: where you go, what
    /// you undo, and what language you are in. The design replaced the old
    /// right-hand control column with keys placed inside the grid — see
    /// `gridControls` — so this is now the only column whose geometry never
    /// depends on the content grid.
    ///
    /// Row 3 is the language slot. iOS will not accept a synthesised tap on
    /// the keyboard switcher, so when the system asks for one, a real globe
    /// button takes that slot and Typikey's own EN/MS toggle keeps its cell
    /// on the home board; when it doesn't, the EN/MS key takes the slot.
    private var pinnedColumn: [(KeyAction, String)?] {
        [(.home, "Home"),
         (.clearAll, clearArmedAt == nil ? "Clear" : "tap again"),
         // Two lines with the second struck through in red, as drawn: the
         // word says what goes, and the strike says it goes away.
         (.deleteWord, lang == .ms ? "Padam\nkata" : "Delete\nword"),
         needsInputModeSwitchKey ? nil : (.language, lang == .en ? "EN" : "MS")]
    }

    /// allCategories() index of the Chat board (offset 1 for Recents).
    private var chatWordsIndex: Int {
        (vocabulary.firstIndex { $0.en == "Chat" } ?? 0) + 1
    }

    /// allCategories() index of the Web board (offset 1 for Recents).
    private var webWordsIndex: Int {
        (vocabulary.firstIndex { $0.en == "Web" } ?? 0) + 1
    }

    /// Spec: applied once when the keyboard attaches to a field; never
    /// switches mid-typing. Manual navigation always wins afterwards.
    ///
    /// Keyboard extensions have no field-identity API, so `viewWillAppear`
    /// only recomputes this mapping when the field's keyboardType/
    /// returnKeyType signature differs from the last one THIS INSTANCE
    /// saw (`lastIntentSignature`, plain in-memory — correct whenever the
    /// instance itself survives the reshow, e.g. ordinary backgrounding/
    /// foregrounding of a still-visible keyboard).
    ///
    /// Tapping the in-keyboard ⌄ key (`commit(.dismiss)`) can additionally
    /// tear down and recreate the whole controller instance before the
    /// field is retapped — instance survival across that specific
    /// dismiss+retap is NOT an API guarantee either way, so
    /// `commit(.dismiss)` also writes the current signature, level, and
    /// a timestamp to UserDefaults via `persistPendingRestore`.
    /// `viewWillAppear` calls `consumePendingRestore` UNCONDITIONALLY,
    /// once, at the very top of every appearance — on every instance,
    /// regardless of whether that instance's own `lastIntentSignature`
    /// already matches — and the note is always read and cleared
    /// together in that one call. It is applied only if the signature
    /// still matches and it is no older than `pendingRestoreTTL` (120s).
    /// That unconditional consume is what keeps the note from surviving
    /// past the single reshow it was written for: a note nobody follows
    /// up on (dismissed, never retapped) cannot linger to ambush some
    /// unrelated later field that happens to share the same signature —
    /// it is gone (read and cleared) the very next time ANY field
    /// attaches, matching or not.
    ///
    /// Known accepted miss: retapping a *different* field that happens
    /// to share the exact same signature within the TTL window of a
    /// dismiss inherits the dismissed field's level instead of getting a
    /// fresh mapping — there is no way to tell that case apart from a
    /// re-show of the same field.
    private func applyIntentLevel() {
        switch textDocumentProxy.keyboardType {
        case .numberPad?, .decimalPad?, .phonePad?:
            level = .numbers; return
        case .emailAddress?, .URL?:
            // An address is spelled, not chosen from a board.
            level = .letters; return
        case .webSearch?:
            // A search box wants whole words — "YouTube", "how to" — far
            // more than it wants letters, and letters are one tap away.
            level = .words(webWordsIndex); return
        case .asciiCapable?:
            level = .letters; return
        default:
            break
        }
        switch textDocumentProxy.returnKeyType {
        case .google?, .yahoo?: level = .words(webWordsIndex)
        case .search?: level = .words(webWordsIndex)
        case .send?: level = .words(chatWordsIndex)
        default: level = .home
        }
    }

    /// A restore only makes sense moments after a dismiss — past this
    /// age a note is more likely to ambush some unrelated later field
    /// than to reflect a genuine reshow, so consumePendingRestore treats
    /// it as absent (while still clearing it).
    private let pendingRestoreTTL: TimeInterval = 120

    /// Called right before `dismissKeyboard()` so the level survives even
    /// if dismissing tears down this controller instance.
    private func persistPendingRestore(signature: String, level: Level) {
        let defaults = UserDefaults.standard
        defaults.set(signature, forKey: "pendingRestoreSignature")
        defaults.set(Date().timeIntervalSince1970, forKey: "pendingRestoreTimestamp")
        switch level {
        case .home: defaults.set("home", forKey: "pendingRestoreLevel")
        case .categories: defaults.set("categories", forKey: "pendingRestoreLevel")
        case .letters: defaults.set("letters", forKey: "pendingRestoreLevel")
        case .numbers: defaults.set("numbers", forKey: "pendingRestoreLevel")
        case .words(let index):
            defaults.set("words", forKey: "pendingRestoreLevel")
            defaults.set(index, forKey: "pendingRestoreWordsIndex")
        }
    }

    /// Reads AND clears any pending restore from a prior dismiss —
    /// called unconditionally, once, at the top of every
    /// `viewWillAppear`, regardless of whether the caller's own
    /// `lastIntentSignature` already matches. That unconditional call is
    /// what guarantees a note never outlives the single appearance it
    /// was written for: it is gone after this one read, whether or not
    /// it matched. Returns the saved level only when the signature still
    /// matches and the note is fresh (see `pendingRestoreTTL`); returns
    /// nil (having still cleared it) otherwise.
    private func consumePendingRestore(matching signature: String) -> Level? {
        let defaults = UserDefaults.standard
        let pendingSignature = defaults.string(forKey: "pendingRestoreSignature")
        let pendingLevel = defaults.string(forKey: "pendingRestoreLevel")
        let pendingWordsIndex = defaults.integer(forKey: "pendingRestoreWordsIndex")
        let pendingTimestamp = defaults.object(forKey: "pendingRestoreTimestamp") as? TimeInterval
        defaults.removeObject(forKey: "pendingRestoreSignature")
        defaults.removeObject(forKey: "pendingRestoreLevel")
        defaults.removeObject(forKey: "pendingRestoreWordsIndex")
        defaults.removeObject(forKey: "pendingRestoreTimestamp")
        guard pendingSignature == signature,
              let pendingTimestamp, Date().timeIntervalSince1970 - pendingTimestamp <= pendingRestoreTTL
        else { return nil }
        switch pendingLevel {
        case "home": return .home
        case "categories": return .categories
        case "letters": return .letters
        case "numbers": return .numbers
        case "words": return .words(pendingWordsIndex)
        default: return nil
        }
    }

    /// Go key follows the field, like the system keyboard's return key.
    private func goLabel() -> String {
        switch textDocumentProxy.returnKeyType {
        case .search?, .google?, .yahoo?: return "Search"
        case .send?: return "Send"
        case .go?: return "Go"
        case .done?: return "Done"
        default: return "return"
        }
    }

    /// A content cell that can span multiple grid slots (e.g. a wide
    /// space bar, or a big 2x2 category tile). Default span is 1x1 — a
    /// normal single cell.
    private struct ContentCell {
        let action: KeyAction
        let label: String
        let colSpan: Int
        let rowSpan: Int

        init(_ action: KeyAction, _ label: String, colSpan: Int = 1, rowSpan: Int = 1) {
            self.action = action
            self.label = label
            self.colSpan = colSpan
            self.rowSpan = rowSpan
        }
    }

    /// The home board, named word by word.
    ///
    /// Four rows leave 33 word cells and Core is 54 words, so home cannot
    /// simply be "all of Core" — it has to be chosen. What earns a cell
    /// here is what a sentence cannot be built without: every pronoun, the
    /// auxiliaries, the few verbs that combine with everything, and the
    /// closed classes. "I am waiting" is a dead end without `for`, which
    /// is why `for` is here and `where` is not.
    ///
    /// Every word named here is defined once, in the Core category. This
    /// list only decides what is one tap away instead of two.
    /// `yesterday` and `tomorrow` are here in place of `a` and `the`, and
    /// that swap is deliberate. Time words are the whole tense mechanism —
    /// without one on this board, past tense costs three taps through
    /// Categories and nobody will pay it, which makes the feature
    /// decorative. Dropping an article costs "I want the book" becoming "I
    /// want book": telegraphic, and understood. Dropping tense costs "I go"
    /// when he meant "I went", which is simply the wrong thing said. Both
    /// articles are still one tap away on Core.
    private static let homeSelection = [
        "I", "you", "he", "she", "it", "we", "they",
        "be", "do", "have", "can", "will",
        "want", "like", "go", "help", "stop",
        "not", "more",
        "to", "for", "with", "in", "on",
        "and", "my", "yesterday", "tomorrow",
        "what", "yes", "no", ".", "?",
    ]

    private var homeWords: [VocabWord] {
        // Looked up across the whole vocabulary rather than in one
        // category: home draws on Core and Little words both, and which
        // board a word is filed under is not home's business.
        let words = Self.homeSelection.compactMap { vocabIndex[$0] }
        // A name that stops matching a Core word would simply vanish from
        // the board — silently, with no crash and no gap, because the
        // packer closes up behind it. That is exactly the class of bug
        // that cost us the `be` key for a whole build.
        assert(words.count == Self.homeSelection.count,
               "homeSelection names a word that is not in Core")
        return words
    }

    private func wordCell(_ word: VocabWord) -> ContentCell {
        var text = word.text(lang)
        // Verb keys follow the sentence: after "I am", `go` reads `going`.
        // The cell does not move — this is the same relabel-in-place
        // mechanism as the language switch (invariants 1 and 7). English
        // only; Malay marks tense with particles, not inflection.
        if word.wordClass == .verb, lang == .en, smartGrammar {
            let inflected = Grammar.inflect(text, as: verbForm, subject: verbSubject)
            if inflected != text {
                inflectionBase[inflected] = text
                text = inflected
            }
        }
        return ContentCell(word.wordClass == .punct ? .punct(text) : .word(text), text)
    }

    private func contentRows(for level: Level) -> [[ContentCell?]] {
        switch level {
        case .home:
            var cells = [ContentCell(.toCategories, "Categories"),
                         ContentCell(.toLetters, "abc")]
            // EN/MS only needs a board cell when the globe has taken the
            // pinned language slot; otherwise it IS the pinned slot, and a
            // second copy here would be two keys for one job.
            if needsInputModeSwitchKey {
                cells.append(ContentCell(.language, lang == .en ? "EN" : "MS"))
            }
            cells += homeWords.map(wordCell)
            return board(cells)
        case .categories:
            // Wide, short tiles rather than the old 2x2 blocks: now that
            // four grid slots belong to Enter, ⌄ and →, a 2x2 tiling no
            // longer fits eleven categories into four rows — and a category
            // that needs a taller keyboard to reach is one he won't find.
            let span = contentColumns >= 10 ? 2 : 1
            return board(allCategories().enumerated().map {
                ContentCell(.toWords($0.offset), $0.element.name, colSpan: span)
            })
        case .words(let index):
            let categories = allCategories()
            let words = index < categories.count ? categories[index].words : []
            guard !words.isEmpty else {
                return board([emptyHint(forCategoryAt: index, of: categories.count)])
            }
            return board(words.map(wordCell))
        case .letters:
            var rows: [[ContentCell?]] = [
                "qwertyuiop".map { Optional(ContentCell(.char(String($0)), String($0))) },
                "asdfghjkl".map { Optional(ContentCell(.char(String($0)), String($0))) } + [Optional(ContentCell(.shift, "⇧"))],
                "zxcvbnm".map { Optional(ContentCell(.char(String($0)), String($0))) }
                    + [Optional(ContentCell(.char(","), ",")), Optional(ContentCell(.char("."), ".")), Optional(ContentCell(.char("?"), "?"))],
                typingBottomRow(switchingTo: ContentCell(.toNumbers, "123", colSpan: 2)),
            ]
            rows[2] += Array(repeating: nil, count: 10 - rows[2].count)
            return rows
        case .numbers:
            var rows: [[ContentCell?]] = [
                "1234567890".map { Optional(ContentCell(.char(String($0)), String($0))) },
                ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { Optional(ContentCell(.char($0), $0)) },
                [".", ",", "?", "!", "'"].map { Optional(ContentCell(.char($0), $0)) },
                typingBottomRow(switchingTo: ContentCell(.toLetters, "abc", colSpan: 2)),
            ]
            rows[2] += Array(repeating: nil, count: 10 - rows[2].count)
            return rows
        }
    }

    /// Mine's empty state isn't Recents' "used often" story — same English
    /// hint in both languages (invariant 8: no new Malay strings). Mine is
    /// always the last category `allCategories()` appends, so that's the
    /// robust way to detect it — never a name string match. Recents' hint
    /// jumps to Core (toWords(1)) since its text points there; Mine's hint
    /// has nowhere in particular to go, so it backs out to the picker.
    private func emptyHint(forCategoryAt index: Int, of count: Int) -> ContentCell {
        let isMine = index == count - 1
        let hint = isMine
            ? "Add words in the Typikey app"
            : (lang == .ms
                ? "Perkataan yang kerap digunakan akan muncul di sini"
                : "Words you use often will appear here")
        return ContentCell(isMine ? .toCategories : .toWords(1), hint, colSpan: contentColumns)
    }

    /// The controls the design places inside the content grid: Enter at
    /// double width on the second row, and the two keys in the bottom-right
    /// corner. Nothing else — the board carries the design's controls and
    /// no others, so tense is read from the sentence's own time words
    /// rather than from a key of its own.
    ///
    /// `board` lays these down before any word, so a word can never be
    /// silently overwritten by one — which is how cells used to vanish.
    private func gridControls(rows rowCount: Int) -> [(cell: ContentCell?, row: Int, col: Int)] {
        let cols = contentColumns
        return [
            (ContentCell(.ret, goLabel(), colSpan: 2), 1, cols - 2),
            (ContentCell(.dismiss, "Hide keyboard"), rowCount - 1, cols - 2),
            (ContentCell(.cursorRight, "Cursor right"), rowCount - 1, cols - 1),
        ]
    }

    /// How many word cells a board actually has, once the design's
    /// controls have taken theirs. Derived from `gridControls` rather than
    /// written down a second time, so moving a control can never leave a
    /// stale number behind.
    private var wordSlots: Int {
        let reserved = gridControls(rows: wordBoardRows)
            .reduce(0) { $0 + ($1.cell?.colSpan ?? 1) }
        return max(0, wordBoardRows * contentColumns - reserved)
    }

    /// Packs cells row-major into a word board, around the fixed controls.
    /// A cell that doesn't fit the free run where it lands slides right and
    /// then down, so a wide cell never straddles a control.
    private func board(_ cells: [ContentCell]) -> [[ContentCell?]] {
        let cols = contentColumns
        let rowCount = wordBoardRows
        var rows: [[ContentCell?]] = Array(
            repeating: Array(repeating: nil, count: cols), count: rowCount)
        var taken = Set<Int>()

        func place(_ cell: ContentCell, row: Int, col: Int) {
            rows[row][col] = cell
            for r in row..<min(row + cell.rowSpan, rowCount) {
                for c in col..<min(col + cell.colSpan, cols) { taken.insert(r * cols + c) }
            }
        }
        for control in gridControls(rows: rowCount) {
            if let cell = control.cell {
                place(cell, row: control.row, col: control.col)
            } else {
                taken.insert(control.row * cols + control.col) // reserved, undrawn
            }
        }

        var next = 0
        for row in 0..<rowCount {
            var col = 0
            while col < cols, next < cells.count {
                let span = min(cells[next].colSpan, cols)
                let free = col + span <= cols
                    && !(col..<(col + span)).contains { taken.contains(row * cols + $0) }
                if free {
                    place(cells[next], row: row, col: col)
                    next += 1
                    col += span
                } else {
                    col += 1
                }
            }
        }
        // A board with more cells than slots loses the overflow without a
        // trace: no gap, no crash, the word simply is not there. Core grew
        // to 54 words on a 36-cell board that way, and eleven of them
        // existed on no board in the app at all. Narrow layouts genuinely
        // cannot hold everything, so the check is for the full-width case,
        // which is where a category is supposed to fit.
        assert(isCompact || next == cells.count,
               "board dropped \(cells.count - next) cells with no way to reach them")
        return rows
    }

    /// The typing levels keep their own bottom row. Enter cannot sit on row
    /// 1 there without displacing a letter, and bottom-right is where every
    /// keyboard puts it anyway.
    ///
    /// The two character-level tools the design drops from the word boards
    /// live here, and only here: single-character delete and ←. A word board
    /// produces whole words, so whole-word delete is the right unit there;
    /// the moment you are spelling something out, one wrong letter is the
    /// likeliest mistake and the cursor has to be able to go back to it.
    private func typingBottomRow(switchingTo other: ContentCell) -> [ContentCell?] {
        var row: [ContentCell?] = Array(repeating: nil, count: 10)
        row[0] = ContentCell(.space, "space", colSpan: 2)
        row[2] = other
        row[4] = ContentCell(.delete, "⌫")
        row[5] = ContentCell(.ret, goLabel(), colSpan: 2)
        row[7] = ContentCell(.cursorLeft, "Cursor left")
        row[8] = ContentCell(.dismiss, "Hide keyboard")
        row[9] = ContentCell(.cursorRight, "Cursor right")
        return row
    }

    /// Four rows, as drawn. The extra height at Large buys taller keys
    /// rather than more of them — at 640pt a row is about 146pt, which is
    /// the easiest target this board has ever had (team decision, 8 Aug).
    ///
    /// The cost is real and is paid in `homeSelection`: 33 word cells for
    /// a 54-word Core, so home has to be curated rather than simply
    /// holding everything.
    ///
    /// A compact phone keeps its 8 rows: it is not an occasional squeeze
    /// like Split View, it's the whole device, so every cell has to stay
    /// reachable in 5 columns.
    private var wordBoardRows: Int {
        UIDevice.current.userInterfaceIdiom == .phone && isCompact ? 8 : 4
    }

    // MARK: Building

    private func buildSuggestionBar() {
        for i in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 23, weight: .semibold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.65
            // Filled pill, not tinted text: a suggestion is a target to be
            // hit, so it has to look as tappable as a key.
            button.backgroundColor = Palette.suggestionFill
            button.setTitleColor(Palette.action, for: .normal)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = Palette.suggestionBorder.cgColor
            button.tag = i
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            trackingView.addSubview(button)
            suggestionButtons.append(button)
        }
    }

    private func buildKeys() {
        keys.forEach { $0.view.removeFromSuperview() }
        keys = []
        // A mid-slide rebuild (e.g. clear-all's relabel, a level switch)
        // can shrink the key count while a touch is still moving; a stale
        // highlightedIndex from the old, larger array would then index
        // out of bounds in the next touchMoved restyle.
        highlightedIndex = nil
        globeButton?.removeFromSuperview()
        globeButton = nil

        // Recomputed here, on every rebuild, so the board is right no
        // matter what caused it — a level change back from the letters
        // keyboard, a re-show, or the sentence simply moving on.
        let context = contextBefore()
        verbForm = (lang == .en && smartGrammar) ? Grammar.verbForm(after: context) : .base
        verbSubject = (lang == .en && smartGrammar) ? Grammar.subject(before: context) : nil
        inflectionBase.removeAll()

        let content = contentRows(for: level)
        contentRowCount = content.count

        // The pinned column is ALWAYS 4 rows (invariant 9) even when the
        // content grid runs 8 rows on a phone — layoutKeys() gives the two
        // grids independent row heights.
        for (row, definition) in pinnedColumn.enumerated() {
            if let definition { addKey(definition, row: row, col: 0) }
        }
        for (row, cells) in content.enumerated() {
            for (i, cell) in cells.enumerated() {
                if let cell {
                    addKey((cell.action, cell.label), row: row, col: i + 1, colSpan: cell.colSpan, rowSpan: cell.rowSpan)
                }
            }
        }

        // The globe is the one key iOS insists on owning — a synthesised
        // tap will not open the keyboard list — so it is a real button
        // rather than a KeyView, dressed to match its neighbours. It fills
        // the pinned column's bottom slot: the design's position, and the
        // one every iOS keyboard uses.
        if needsInputModeSwitchKey {
            let globe = UIButton(type: .system)
            globe.setImage(UIImage(systemName: "globe"), for: .normal)
            globe.tintColor = Palette.foreground(on: Palette.erase)
            globe.backgroundColor = Palette.erase
            globe.layer.cornerRadius = 16
            globe.layer.cornerCurve = .continuous
            globe.layer.borderWidth = 1
            globe.layer.borderColor = Palette.erase.darkened(by: 0.16).cgColor
            globe.accessibilityLabel = "Change keyboard"
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            trackingView.addSubview(globe)
            globeButton = globe
        }

        updateSuggestions()
        view.setNeedsLayout()
    }

    private func addKey(_ def: (KeyAction, String), row: Int, col: Int, colSpan: Int = 1, rowSpan: Int = 1) {
        let keyLabel = KeyView()
        style(keyLabel, action: def.0, label: def.1, highlighted: false)
        trackingView.addSubview(keyLabel)
        keys.append(Key(action: def.0, label: def.1, view: keyLabel, row: row, col: col, colSpan: colSpan, rowSpan: rowSpan))
    }

    /// Which of the three jobs a key does. The role decides its color, and
    /// the color is the only thing the user needs to read to know whether a
    /// key will write, travel, or undo.
    private enum KeyRole { case write, navigate, erase, action }

    private func role(of action: KeyAction) -> KeyRole {
        switch action {
        case .word, .punct, .char, .space:
            return .write
        case .ret:
            return .action // Enter finishes the message; the design's one blue key
        case .home, .toCategories, .toWords, .toLetters, .toNumbers, .language,
             .shift, .cursorLeft, .cursorRight, .dismiss:
            return .navigate
        case .delete, .deleteWord, .clearAll:
            return .erase
        }
    }

    /// The controls the design draws as glyphs rather than words.
    private func symbolName(for action: KeyAction) -> String? {
        switch action {
        case .home: return "house.fill"
        case .toCategories: return "square.grid.2x2.fill"
        case .dismiss: return "keyboard.chevron.compact.down"
        case .cursorRight: return "arrow.right"
        case .cursorLeft: return "arrow.left"
        default: return nil
        }
    }

    private func symbolImage(_ name: String, tint: UIColor) -> NSAttributedString {
        let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        return NSAttributedString(attachment: attachment)
    }

    private func style(_ label: KeyView, action: KeyAction, label text: String, highlighted: Bool) {
        var background: UIColor
        switch role(of: action) {
        case .write:
            if case .word(let w) = action, let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w] {
                background = word.wordClass.color
            } else if case .word = action {
                background = WordClass.social.color // a word of the user's own
            } else {
                background = Palette.paper
            }
        case .navigate:
            // Home has no card in the design — it sits directly on the
            // tray, in the tray's own colour, so only the glyph reads.
            background = action == .home ? Palette.board : Palette.navigate
        case .action:
            background = Palette.action
        case .erase:
            // Armed clear-all is the one irreversible key; it announces
            // itself in red rather than relying on the label change alone.
            background = isClearAllArmed(action) ? Palette.destructive : Palette.erase
        }

        let foreground = Palette.foreground(on: background)
        // Home is the one key the design draws with no card at all — it
        // sits directly on the tray.
        label.paint(fill: background, focused: highlighted, bordered: action != .home)
        label.textColor = foreground
        // Phrases have to be allowed to wrap; a control label is one word
        // and should shrink rather than break across lines. Delete word is
        // two, because that is how it is drawn.
        label.lines = role(of: action) == .write ? 3 : (action == .deleteWord ? 2 : 1)
        label.spokenLabel = nil

        // Four controls are glyphs in the design. Drawing them as an image
        // inside the same label keeps every key on one code path; the
        // spoken label carries the name so VoiceOver and the tests read
        // the board a sighted user sees.
        if let symbol = symbolName(for: action) {
            // Home is grey rather than blue: it is not one of the keys that
            // send you somewhere new, it is the way back to where you were.
            let tint = action == .home ? UIColor(white: 0.58, alpha: 1) : foreground
            label.attributedText = symbolImage(symbol, tint: tint)
            label.spokenLabel = text
            return
        }

        switch action {
        case .word(let w):
            if let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w], let emoji = word.emoji {
                // Word on top, symbol underneath, as drawn: the word is
                // what gets typed, and the symbol is the recognition cue.
                let content = NSMutableAttributedString(
                    string: text + "\n", attributes: [
                        .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
                        .foregroundColor: foreground,
                    ])
                content.append(NSAttributedString(
                    string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 22)]))
                label.attributedText = content
                // The cell is called by its word. Without this a screen
                // reader announces "want raised hands", and the symbol —
                // which exists to be glanced at, not read — ends up being
                // read aloud on every single key.
                label.spokenLabel = text
            } else {
                label.attributedText = nil
                label.font = .systemFont(ofSize: 21, weight: .semibold)
                label.text = text
            }
        case .deleteWord:
            // The strike falls on the second line only — it is the word
            // that goes, and the red line is what says so.
            let content = NSMutableAttributedString(
                string: text, attributes: [
                    .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
                    .foregroundColor: foreground,
                ])
            if let newline = text.range(of: "\n") {
                let start = text.distance(from: text.startIndex, to: newline.upperBound)
                content.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: Palette.destructive,
                ], range: NSRange(location: start, length: (text as NSString).length - start))
            }
            label.attributedText = content
            // Two drawn lines, one spoken name.
            label.spokenLabel = text.replacingOccurrences(of: "\n", with: " ")
        case .punct:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 30, weight: .semibold)
            label.text = text
        case .char:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 32, weight: .medium)
            label.text = level == .letters && shifted ? text.uppercased() : text
        case .home, .toCategories, .toWords, .toLetters, .toNumbers, .language, .shift:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 18, weight: .semibold)
            label.text = text
        default:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 19, weight: .medium)
            label.text = text
        }
    }

    private func isClearAllArmed(_ action: KeyAction) -> Bool {
        if case .clearAll = action { return clearArmedAt != nil }
        return false
    }

    private func restyleAll() {
        for (i, key) in keys.enumerated() {
            style(key.view, action: key.action, label: key.label, highlighted: i == highlightedIndex)
        }
    }

    // MARK: Layout

    private func layoutKeys() {
        let fullBounds = trackingView.bounds
        var bounds = fullBounds
        // viewDidLayoutSubviews compensates the height REQUEST when the
        // system grants less than we asked for; this clamp is only a
        // defensive floor for the transient frame before that lands, so
        // it targets the raw preset — not the (possibly inflated)
        // requested height — and converges to the designed size.
        bounds.size.height = min(bounds.height, min(view.bounds.height > 0 ? view.bounds.height : sizePresets[sizeIndex], sizePresets[sizeIndex]))
        guard bounds.width > 0, !keys.isEmpty else { return }
        let yOffset = fullBounds.height - bounds.height
        layoutYOffset = yOffset
        boardBackground.frame = CGRect(
            x: 0, y: yOffset, width: fullBounds.width, height: fullBounds.height - yOffset)
        let inset: CGFloat = 4

        // The globe moved into the pinned column, so the suggestion bar
        // gets the full width back for its three chips.
        let slotWidth = (bounds.width - inset * 2) / 3
        for (i, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(
                x: inset + CGFloat(i) * slotWidth + 3, y: yOffset + inset,
                width: slotWidth - 6, height: topBarHeight - inset * 2)
        }

        // The pinned column is sized from bounds.width alone — never from
        // contentColumns — so col 0 lands on the exact same frame whether
        // the content grid is 5 columns (compact) or 10 (full width and
        // the typing levels). One pinned column plus ten content columns
        // is eleven, so at full width every key is bounds.width / 11 wide.
        let pinnedW = bounds.width / 11
        let contentW = (bounds.width - pinnedW) / CGFloat(contentColumns)
        let gridTop = yOffset + topBarHeight
        // The pinned column always divides the band into 4 (invariant 9:
        // its frames never depend on the content grid); the content grid
        // rows can be 8 on a phone.
        let pinnedRowH = (fullBounds.height - gridTop) / 4
        let contentRowH = (fullBounds.height - gridTop) / CGFloat(max(contentRowCount, 4))
        // A transient sub-topBarHeight container (before the height
        // compensation above lands) would otherwise yield negative
        // frames here — bail rather than draw them.
        guard pinnedRowH > 0 else { return }

        for key in keys {
            let pinned = key.col == 0
            let x = pinned ? 0 : pinnedW + CGFloat(key.col - 1) * contentW
            let width = pinned ? pinnedW : contentW * CGFloat(key.colSpan)
            let rowH = pinned ? pinnedRowH : contentRowH
            key.view.frame = CGRect(
                x: x + 3,
                y: gridTop + CGFloat(key.row) * rowH + 3,
                width: width - 6, height: rowH * CGFloat(key.rowSpan) - 6)
        }

        // The globe is a real button rather than a Key, so it is placed by
        // hand — on the pinned column's bottom slot, the same frame the
        // EN/MS key would occupy if iOS were not asking for a switcher.
        globeButton?.frame = CGRect(
            x: 3, y: gridTop + 3 * pinnedRowH + 3,
            width: pinnedW - 6, height: pinnedRowH - 6)

        recordFit(rowHeight: contentRowH)
    }

    /// Publishes the height the system actually granted, so the app can say
    /// whether the whole board fits. Only the extension can see this
    /// number, and "is the bottom row cut off?" is otherwise a question
    /// nobody can answer without photographing a screen.
    ///
    /// Written straight to the store rather than through `learn`: this is
    /// geometry, not something he said, and private mode's promise is about
    /// the latter. Recorded only when it changes, since layout runs often.
    private func recordFit(rowHeight: CGFloat) {
        let reading = KeyboardFit.Reading(
            requested: requestedHeight,
            granted: view.bounds.height,
            rowHeight: rowHeight,
            rows: contentRowCount)
        let signature = "\(Int(reading.requested))|\(Int(reading.granted))|\(Int(reading.rowHeight))|\(reading.rows)"
        guard signature != lastFitSignature else { return }
        lastFitSignature = signature
        KeyboardFit.record(reading, in: store)
    }

    // MARK: Explore-then-commit (called by TrackingView)

    fileprivate func touchMoved(to point: CGPoint) {
        let index = keyIndex(at: point)
        guard index != highlightedIndex else { return }
        // Crossing onto a new key is the moment the user needs confirming:
        // sliding is free exploration, so this tick is how the board is read
        // by feel rather than by eye.
        if index != nil { haptics.slidToNewKey() }
        let old = highlightedIndex
        highlightedIndex = index
        if let old { style(keys[old].view, action: keys[old].action, label: keys[old].label, highlighted: false) }
        if let index { style(keys[index].view, action: keys[index].action, label: keys[index].label, highlighted: true) }
    }

    fileprivate func touchLifted(at point: CGPoint) {
        let index = keyIndex(at: point)
        highlightedIndex = nil
        restyleAll()
        guard let index else { return }
        commit(keys[index].action)
    }

    fileprivate func touchCancelled() {
        highlightedIndex = nil
        restyleAll()
    }

    /// No dead zones: any point below the suggestion bar maps to the
    /// nearest key by center distance. The globe is a real button filling
    /// its whole pinned slot, so it takes its own touches before this runs
    /// and only the 3pt gutters around it fall through to a neighbour.
    private func keyIndex(at point: CGPoint) -> Int? {
        guard point.y > layoutYOffset + topBarHeight else { return nil } // suggestion buttons handle themselves
        var best: (index: Int, distance: CGFloat)?
        for (i, key) in keys.enumerated() {
            if key.view.frame.contains(point) { return i }
            let c = CGPoint(x: key.view.frame.midX, y: key.view.frame.midY)
            let d = hypot(c.x - point.x, c.y - point.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }

    // MARK: Committing

    private func commit(_ action: KeyAction) {
        // Double-tap guard; delete, word-delete, clear-all, and the
        // cursor arrows are exempt — repeats are intentional for those.
        if !isDebounceExempt(action),
           let last = lastCommit, last.action == action,
           Date().timeIntervalSince(last.at) < debounceInterval {
            return
        }
        haptics.commit()
        lastCommit = (action, Date())

        switch action {
        case .word(let w):
            insertWord(w)
        case .punct(let p):
            terminateToken()
            insertPunctuation(p)
        case .char(let c):
            // An apostrophe is token-internal (so "don't" accumulates as
            // one token) even though it isn't a letter — terminateToken's
            // ≥3 requirement below counts letters only, so it doesn't
            // inflate the count, but the stored/counted key keeps it.
            if let ch = c.first, c.count == 1, ch.isLetter || ch == "'" || ch == "\u{2019}" {
                typedToken += c.lowercased()
            } else {
                terminateToken()
            }
            textDocumentProxy.insertText(shifted ? c.uppercased() : c)
            if shifted { shifted = false; restyleAll() }
        case .shift:
            shifted.toggle()
            restyleAll()
        case .delete:
            // Deleting mid-word makes the accumulated token unreliable —
            // reset rather than count a partial/garbled word.
            typedToken = ""
            textDocumentProxy.deleteBackward()
        case .deleteWord:
            typedToken = ""
            deleteLastWord()
        case .home:
            typedToken = ""
            completionWords = []
            level = .home; buildKeys()
        case .toCategories:
            typedToken = ""
            completionWords = []
            level = .categories; buildKeys()
        case .toWords(let i):
            typedToken = ""
            completionWords = []
            level = .words(i); buildKeys()
        case .toLetters:
            typedToken = ""
            completionWords = []
            level = .letters; buildKeys()
        case .toNumbers:
            typedToken = ""
            completionWords = []
            level = .numbers; buildKeys()
        case .clearAll:
            typedToken = ""
            completionWords = []
            handleClearAll()
        case .cursorLeft:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        case .cursorRight:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        case .space:
            terminateToken()
            textDocumentProxy.insertText(" ")
        case .ret:
            terminateToken()
            textDocumentProxy.insertText("\n")
        case .dismiss:
            let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
            persistPendingRestore(signature: signature, level: level)
            dismissKeyboard()
        case .language:
            completionWords = []
            // Same positions, new labels — muscle memory survives the switch.
            lang = lang == .en ? .ms : .en
            store.set(lang.rawValue, forKey: "lang")
            buildKeys()
        }
        updateSuggestions()
        requestPhraseCompletion()
        // The document proxy can lag its own insertion by a run loop, so a
        // form change caused by THIS commit is not always visible to
        // textDidChange when it fires. Re-check once the text has settled:
        // that is what was leaving the board in the past tense after a full
        // stop had already ended the sentence. refreshVerbForms rebuilds
        // only when the board would actually read differently, so this
        // costs nothing on the commits that change nothing.
        DispatchQueue.main.async { [weak self] in self?.refreshVerbForms() }
    }

    /// Repeats are intentional for deletes and cursor movement; clear-all
    /// has its own two-tap arm and must not have its second tap swallowed.
    private func isDebounceExempt(_ action: KeyAction) -> Bool {
        switch action {
        case .delete, .deleteWord, .clearAll, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    private func handleClearAll() {
        if let armed = clearArmedAt, Date().timeIntervalSince(armed) < 3 {
            clearArmedAt = nil
            clearAllText()
            buildKeys() // restore the "Clear all" label
            return
        }
        clearArmedAt = Date()
        haptics.armedDestructive() // the next tap erases everything — say so by feel
        buildKeys() // relabel to "tap again"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.clearArmedAt != nil else { return }
            if Date().timeIntervalSince(self.clearArmedAt!) >= 3 {
                self.clearArmedAt = nil
                self.buildKeys() // disarm quietly
            }
        }
    }

    /// Clears everything the field exposes. Extensions only see a context
    /// window; in his real use (messages, search) that is the whole text.
    private func clearAllText() {
        if let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
        }
        var passes = 0
        while let before = textDocumentProxy.documentContextBeforeInput,
              !before.isEmpty, passes < 200 {
            for _ in 0..<before.count { textDocumentProxy.deleteBackward() }
            passes += 1
        }
    }

    private func contextBefore() -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    /// True at the start of the document or after sentence-ending punctuation.
    private func atSentenceStart() -> Bool {
        let trimmed = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return ".!?".contains(last)
    }

    /// Last completed word before the cursor, for prediction and learning.
    private func lastWord() -> String {
        let context = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        let token = context.split(whereSeparator: { $0 == " " || $0 == "\n" }).last.map(String.init) ?? ""
        return token.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,"))
    }

    /// One tap = one word. Handles spacing, sentence-start capitalization,
    /// and records usage so Recents and prediction improve over time.
    private func insertWord(_ word: String) {
        let previous = lastWord()

        var text = word
        if atSentenceStart(), let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }
        if let last = contextBefore().last, last != " ", last != "\n" {
            textDocumentProxy.insertText(" ")
        }
        textDocumentProxy.insertText(text + " ")

        // Count the base word, not the inflected label: "go", "goes" and
        // "going" are one key and one habit, and Recents would otherwise
        // fill up with three entries for the same cell.
        let counted = inflectionBase[word] ?? word
        usageCounts[counted, default: 0] += 1
        learn(usageCounts, forKey: "usage")
        if !previous.isEmpty {
            learnedBigrams["\(previous.lowercased())|\(counted)", default: 0] += 1
            learn(learnedBigrams, forKey: "bigrams")
        }
        refreshVerbForms()
    }

    /// Punctuation attaches to the word before it: "hello ." → "hello. "
    private func insertPunctuation(_ p: String) {
        if contextBefore().last == " " {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(p + " ")
    }

    private func deleteLastWord() {
        var context = contextBefore()
        guard !context.isEmpty else { return }
        while let last = context.last, last == " " {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
        while let last = context.last, last != " ", last != "\n" {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
    }

    // MARK: Capture (Task G1 — letters-level typing, not grid-cell taps)

    /// Ends the current typed token — called on a terminator (space,
    /// return, grid punctuation, or a non-letter/non-apostrophe char).
    /// Counts it as a capture candidate when it has ≥3 letters (the
    /// apostrophe in a contraction like "don't" doesn't count toward
    /// that minimum, but stays in the stored/counted key) and isn't
    /// already known; always clears the accumulator either way.
    private func terminateToken() {
        let token = typedToken
        typedToken = ""
        let letterCount = token.filter(\.isLetter).count
        guard letterCount >= 3,
              token.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "\u{2019}" }),
              !isKnownWord(token) else { return }
        // Structured fields (email/URL/search) yield fragments like
        // "gmail" or "com" that are never real vocabulary — skip counting,
        // typing still works normally either way.
        switch textDocumentProxy.keyboardType {
        case .emailAddress?, .URL?, .webSearch?: return
        default: break
        }
        var counts = (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
        counts[token, default: 0] += 1
        learn(counts, forKey: "captureCounts")
    }

    /// Case-insensitive check against myWords and the built-in vocabulary
    /// — `token` is already lowercased by the time it reaches here.
    private func isKnownWord(_ token: String) -> Bool {
        if myWords.contains(where: { $0.lowercased() == token }) { return true }
        return Self.knownVocabWords.contains(token)
    }

    // MARK: Prediction (on-device only — no Full Access, no network)

    /// The spell-check languages this system offers, resolved once.
    private static let checkerLanguages = UITextChecker.availableLanguages

    /// The language the user is ACTUALLY typing, detected from the field's
    /// own text — completions follow the text, not a settings toggle
    /// (Cotypist's "it just works in any language" feel). Falls back to
    /// the manual EN/MS toggle on short or ambiguous context, so nothing
    /// changes for a user who never leaves one language.
    private func completionLanguage() -> String {
        let sample = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(200))
        guard sample.count >= 12 else { return lang.spellCheckCode }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let detected = recognizer.dominantLanguage,
              (recognizer.languageHypotheses(withMaximum: 1)[detected] ?? 0) > 0.7,
              let match = Self.checkerLanguages.first(where: { $0.hasPrefix(detected.rawValue) })
        else { return lang.spellCheckCode }
        return match
    }

    /// Screen learning input: the broadcast extension's word-frequency
    /// store, honored only while fresh. Without Full Access the key simply
    /// never exists in `.standard` and this stays empty.
    /// The single gate every piece of learning passes through. In private
    /// mode it does nothing, so a future feature cannot start remembering
    /// something by forgetting to check a flag — the check lives in one
    /// place rather than at seven call sites.
    private func learn(_ value: Any, forKey key: String) {
        guard !isPrivate else { return }
        store.set(value, forKey: key)
    }

    private func reloadScreenWords() {
        // Screen words are learning too: in private mode they neither
        // accumulate nor influence what is suggested.
        guard !isPrivate else {
            screenWords = [:]
            return
        }
        let stamp = store.double(forKey: ScreenWords.stampKey)
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < 1800 else {
            screenWords = [:]
            return
        }
        screenWords = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int]) ?? [:]
    }

    /// Words that have proved themselves become keys on their own — no
    /// Add button, no trip to the app. Asking a user who needs up to half a
    /// minute per tap to curate a word list is asking for the one thing
    /// this keyboard exists to avoid.
    ///
    /// Two sources qualify, both at three sightings: words typed out
    /// letter by letter, and names read off the screen (capitalized
    /// mid-sentence and unknown to the spell checker, which is what
    /// separates "Hafiz" from "lunch"). Removing a word in My Words blocks
    /// it permanently, so the automatic path stays correctable.
    private func promoteFrequentWords() {
        guard !isPrivate else { return }
        var words = (store.array(forKey: "myWords") as? [String]) ?? []
        let blocked = Set((store.array(forKey: ScreenWords.blockedKey) as? [String] ?? [])
            .map { $0.lowercased() })
        var existing = Set(words.map { $0.lowercased() })
        var added: [String] = []

        func adopt(_ word: String, capitalized: Bool) {
            let lower = word.lowercased()
            guard !existing.contains(lower), !blocked.contains(lower), added.count < 5 else { return }
            existing.insert(lower)
            added.append(capitalized ? word.capitalized : lower)
        }

        var captures = (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
        for (word, count) in captures.sorted(by: { $0.value > $1.value }) where count >= 3 {
            adopt(word, capitalized: false)
            captures.removeValue(forKey: word)
        }

        let names = Set(store.array(forKey: ScreenWords.capsKey) as? [String] ?? [])
        let checker = UITextChecker()
        for (word, count) in screenWords.sorted(by: { $0.value > $1.value })
        where count >= 3 && names.contains(word) {
            // A name is a word the dictionary does not know. "Friday" is
            // capitalized too, and belongs to the dictionary, not to him.
            let range = NSRange(location: 0, length: word.utf16.count)
            let misspelled = checker.rangeOfMisspelledWord(
                in: word, range: range, startingAt: 0, wrap: false, language: "en_US")
            guard misspelled.location != NSNotFound else { continue }
            adopt(word, capitalized: true)
        }

        guard !added.isEmpty else { return }
        words.append(contentsOf: added)
        learn(words, forKey: "myWords")
        learn(captures, forKey: "captureCounts")
        myWords = words
    }

    /// Grid mode: predict likely next words from learned bigrams, seeded
    /// per language. Predictions appear in the suggestion bar so grid
    /// positions stay stable.
    private func predictNextWords() -> [String] {
        let prev = atSentenceStart() ? "" : lastWord().lowercased()
        var scores: [String: Int] = [:]

        let prefix = "\(prev)|"
        for (key, count) in learnedBigrams where key.hasPrefix(prefix) {
            scores[String(key.dropFirst(prefix.count)), default: 0] += count * 10
        }
        for (i, word) in (seedBigrams[lang]?[prev] ?? []).enumerated() {
            scores[word, default: 0] += 3 - i
        }
        // Screen context: words the user is looking at right now are
        // likely in the reply. Weighted above the generic seeds but below
        // any real learned bigram, so personal learning always wins.
        for (word, count) in screenWords.sorted(by: { $0.value > $1.value }).prefix(15) {
            scores[word, default: 0] += min(count, 4)
        }
        return scores.sorted { $0.value > $1.value }.prefix(3).map(\.key)
    }

    private func topVocabulary() -> [String] {
        // myWords go first and are never starved by usage ranking — the
        // user's own words matter for completion regardless of how often
        // built-in vocabulary has been used.
        let ranked = usageCounts.sorted { $0.value > $1.value }.map(\.key)
        let screenTop = screenWords.sorted { $0.value > $1.value }.prefix(10).map(\.key)
        var seen = Set<String>()
        var result: [String] = []
        for word in myWords + screenTop + ranked {
            guard !seen.contains(word) else { continue }
            seen.insert(word)
            result.append(word)
            if result.count == 40 { break }
        }
        return result
    }

    private func requestPhraseCompletion() {
        guard isWordLevel, !completionEngine.isDegraded else {
            completionWords = []
            return
        }
        completionEngine.requestCompletion(
            context: contextBefore(),
            vocabulary: topVocabulary()
        ) { [weak self] completion in
            guard let self else { return }
            self.completionWords = completion?.words ?? []
            self.updateSuggestions()
        }
    }

    private func currentPartialWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        return context.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
    }

    private func updateSuggestions() {
        let titles: [String]
        if isWordLevel {
            if !completionWords.isEmpty {
                // Two chips, no symbols to decode: the short one is the next
                // word, the long one is the whole continuation. Since the
                // long chip starts with the short chip's word, the
                // relationship explains itself.
                var slots: [String] = [completionWords[0]]
                if completionWords.count >= 2 {
                    slots.append(completionWords.joined(separator: " "))
                }
                if let bigram = predictNextWords().first,
                   !slots.contains(bigram),
                   bigram != completionWords[0] {
                    slots.append(bigram)
                }
                titles = Array(slots.prefix(3))
            } else {
                titles = predictNextWords()
            }
        } else {
            let word = currentPartialWord()
            if word.count >= 2 {
                // Screen-learned matches lead: a name or product word seen
                // on screen won't be in the system dictionary at all, and
                // that is exactly the word worth one tap instead of ten.
                let lower = word.lowercased()
                var slots = screenWords
                    .filter { $0.key.hasPrefix(lower) && $0.key != lower }
                    .sorted { $0.value > $1.value }
                    .prefix(2)
                    .map(\.key)
                let checker = UITextChecker()
                let range = NSRange(location: 0, length: word.utf16.count)
                for completion in checker.completions(
                    forPartialWordRange: range, in: word, language: completionLanguage()) ?? [] {
                    if !slots.contains(where: { $0.caseInsensitiveCompare(completion) == .orderedSame }) {
                        slots.append(completion)
                    }
                }
                titles = Array(slots.prefix(3))
            } else {
                titles = []
            }
        }
        for (i, button) in suggestionButtons.enumerated() {
            if i < titles.count {
                button.setTitle(titles[i], for: .normal)
                button.isHidden = false
            } else {
                button.setTitle(nil, for: .normal)
                button.isHidden = true
            }
        }
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        haptics.commit()
        if isWordLevel, !completionWords.isEmpty {
            if title == completionWords[0] {
                insertWord(completionWords[0])
                completionWords = []
                updateSuggestions()
                requestPhraseCompletion()
                return
            }
            if title == completionWords.joined(separator: " ") {
                for word in completionWords { insertWord(word) }
                completionWords = []
                updateSuggestions()
                requestPhraseCompletion()
                return
            }
        }
        if isWordLevel {
            insertWord(title)
        } else {
            // The chip replaces whatever was typed so far with a full
            // suggestion — typedToken no longer matches what's on screen.
            // Reset rather than count: the completed word wasn't typed
            // letter-by-letter, so it isn't a capture candidate.
            typedToken = ""
            let word = currentPartialWord()
            for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(title + " ")
        }
        updateSuggestions()
    }
}

/// Routes raw touches to the controller so keys commit on lift-off
/// rather than touch-down.
private final class TrackingView: UIView, UIInputViewAudioFeedback {
    weak var controller: KeyboardViewController?

    var enableInputClicksWhenVisible: Bool { true }

    // Let touches above the keyboard band fall through to the app instead
    // of being swallowed by a transparent, oversized container.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let controller, point.y < controller.layoutYOffset { return nil }
        return super.hitTest(point, with: event)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchMoved(to: touch.location(in: self))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchMoved(to: touch.location(in: self))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchLifted(at: touch.location(in: self))
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchCancelled()
    }
}
