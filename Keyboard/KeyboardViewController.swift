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

final class KeyboardViewController: UIInputViewController {

    struct SuggestedCorrection: Equatable {
        let original: String
        let replacement: String
        let documentIdentifier: UUID
        let expectedContextSuffix: String
        let terminator: String
    }

    enum KeyAction: Equatable {
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
        /// A page Fadillah built in the app, by id.
        case toPage(String)
        case toLetters
        case toNumbers
        case space
        case ret
        case dismiss
    }

    enum Level: Equatable {
        case home, categories, letters, numbers
        case words(Int) // index into allCategories()
        case page(String) // a page built in the app, by id
    }

    struct Key {
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
    var size: KeyboardSize = .large
    var presetHeight: CGFloat {
        size.height(phone: UIDevice.current.userInterfaceIdiom == .phone)
    }
    var heightConstraint: NSLayoutConstraint?
    var healAttempts = 0
    var lastCompact = false
    let topBarHeight: CGFloat = 56
    let debounceInterval: TimeInterval = 0.5

    // The system can grant the extension's window LESS height than we
    // request (iPadOS 26 reserves an input-assistant band above
    // third-party keyboards). heightDeficit accumulates the measured
    // shortfall so the REQUEST compensates for it; requestedHeight is
    // what we ask the constraint for everywhere we used to ask for the
    // raw preset. Capped at 160 so it can never runaway. The whole request
    // is additionally clamped to 75% of an iPad screen, which leaves room
    // for the reserved band while still reaching the Large preset, and 60%
    // on iPhone so a portrait preset cannot bury an app in landscape.
    var heightDeficit: CGFloat = 0
    var requestedHeight: CGFloat {
        let screenHeight = (view.window?.screen ?? UIScreen.main).bounds.height
        return KeyboardFit.requestedHeight(
            preset: presetHeight,
            measuredDeficit: heightDeficit,
            screenHeight: screenHeight,
            isPhone: UIDevice.current.userInterfaceIdiom == .phone)
    }

    var isCompact: Bool {
        view.bounds.width > 0 && view.bounds.width < 500
    }

    /// Top of the drawn keyboard band inside the container. Non-zero only
    /// when the system hands us an oversized container.
    var layoutYOffset: CGFloat = 0

    /// Paints only the actual keyboard band — the rest of an oversized
    /// container stays transparent instead of a white wall.
    let boardBackground = UIView()
    var isRotating = false
    var pendingHeightFix = false

    var keys: [Key] = []
    var contentRowCount = 4
    var lastFitSignature: String?

    /// Private mode: typing works exactly as always, nothing is remembered.
    /// Re-read on every appearance so a toggle in the app takes effect on
    /// the very next field, not after a restart.
    var isPrivate = false

    /// Whether verb keys follow the sentence. Every AAC product with this
    /// feature ships a way to turn it off; see `Preferences.smartGrammar`.
    var smartGrammar = true

    /// Whether cells the sentence cannot use are re-offered as words it
    /// can. The one feature here that moves a cell, so it has the loudest
    /// switch — see `Preferences.boardFollowsSentence`.
    var boardFollowsSentence = true

    /// The shape the board was last built for. Held so a rebuild happens
    /// when the sentence starts needing something different, and not on
    /// every keystroke.
    var boardSlot: SentenceShape.Slot = .any

    /// The subject the sentence is about, when the last word named one.
    /// Only "be" needs it — it is the one English verb that still inflects
    /// for person as well as tense.
    var verbSubject: String?

    /// The form verb cells are currently showing, recomputed whenever the
    /// text around the cursor changes. Held rather than derived on the fly
    /// so a rebuild is only triggered when the form actually changes.
    var verbForm: Grammar.VerbForm = .base

    /// Inflected label -> the vocabulary word it came from, so a relabelled
    /// key keeps its color and emoji, and usage is counted against the base
    /// word rather than scattering across "go", "going" and "goes".
    var inflectionBase: [String: String] = [:]
    var level: Level = .home
    var clearArmedAt: Date?
    var lastIntentSignature: String?

    // The reference has eight word columns between two fixed edge columns.
    // Typing levels retain ten character columns inside those same edges.
    var contentColumns: Int {
        switch level {
        case .letters, .numbers: return 10
        default: return isCompact ? 5 : 8
        }
    }

    var isWordLevel: Bool {
        switch level {
        case .home, .categories, .words, .page: return true
        case .letters, .numbers: return false
        }
    }
    var shifted = false
    var lastCommit: (action: KeyAction, at: Date)?

    // Haptics are a no-op on iPads (no Taptic Engine) — wired anyway so an
    // iPhone build gets them for free. The input click is the audible
    // press feedback and needs no Full Access.
    let haptics = Haptics()

    let trackingView = TrackingView()
    var suggestionButtons: [UIButton] = []
    var highlightedIndex: Int?
    var touchIntentFilter = TouchIntentFilter()
    var lastTouchEvidence: TouchEvidence?
    var typedTokenTouchEvidence: TouchEvidence?
    var pendingCorrection: SuggestedCorrection?
    var pendingAutomaticCorrection: SuggestedCorrection?
    var appliedCorrection: AppliedCorrection?
    var isApplyingCorrection = false

    // Learned usage, persisted in the extension's own sandbox — no Full
    // Access, no shared containers, nothing leaves the keyboard.
    var usageCounts: [String: Int] = [:]
    var learnedBigrams: [String: Int] = [:]

    // The user's own words (Task G1 capture). Loaded in viewDidLoad and
    // reloaded in viewWillAppear so app-side edits in My Words appear the
    // next time the keyboard shows.
    var myWords: [String] = []

    // Words recently OCR'd off the user's screen by the broadcast
    // extension (screen learning). Read-only here; reaches this process
    // through the app group, so it is empty without Full Access — and the
    // keyboard must work identically either way (invariant 5). Context
    // decays: a session older than 30 minutes stops influencing anything.
    var screenWords: [String: Int] = [:]
    var personalizationSnapshot: PersonalizationSnapshot?

    // Accumulates the current letters-level word as it's typed one key at
    // a time; cleared on any terminator (space/return/punctuation/delete/
    // level change/field switch) so only real letter-by-letter typing is
    // ever counted — grid-cell word taps never touch this.
    var typedToken = ""

    /// Built-in vocabulary text, lowercased, for a case-insensitive
    /// "already known" check when deciding whether a typed token is a
    /// capture candidate.
    static let knownVocabWords: Set<String> = Set(vocabIndex.keys.map { $0.lowercased() })

    /// Persistence home. With Full Access granted, learning and settings
    /// live in the app group so the container app can read and (later)
    /// edit them; without it, everything stays in the extension's own
    /// sandbox exactly as before — the keyboard never REQUIRES the grant.
    lazy var store: UserDefaults = {
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
    let completionEngine = CompletionEngine()
    var completionWords: [String] = []

    // Immediate prediction never waits for the model. The trie is rebuilt
    // only when its small personalization signature changes; every keystroke
    // after that is lookup + ranking.
    var predictionTrie = PrefixTrie(words: [])
    var predictionTrieSignature = ""
    var predictionDocumentIdentifier: UUID?

    var currentDocumentIdentifier: UUID? {
        TextDocumentIdentity.read(from: textDocumentProxy as AnyObject)
    }

    /// Ways of saying what the finished sentence seems to mean, offered
    /// after the question key and cleared by anything else. Held here
    /// rather than recomputed on every rebuild because it is an answer to
    /// one deliberate act — pressing `?` — and not a running commentary.
    var rephrasings: [String] = []

    var autoFileCache: [String: String] = [:]
    let pendingRestoreTTL: TimeInterval = 120

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
        size = KeyboardSize.clamped(Preferences.keyboardSize(in: store))

        // Height lives on OUR content view, never on the root view. The
        // system derives the window height from content fitting; a height
        // constraint on the root view fights the system's cached window
        // frame, and the loser gets re-cached — that feedback loop is what
        // made the keyboard grow on every open/close cycle.
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.isMultipleTouchEnabled = false
        trackingView.controller = self
        view.addSubview(trackingView)
        let height = trackingView.heightAnchor.constraint(equalToConstant: presetHeight)
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trackingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        heightConstraint = height

        boardBackground.backgroundColor = isPrivate ? Palette.privateBoard : Palette.board
        trackingView.addSubview(boardBackground)

        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitPreferredContentSizeCategory.self,
            UITraitLegibilityWeight.self,
        ]) {
            (controller: KeyboardViewController, _) in
            controller.refreshAppearance()
        }

        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        trackingView.addGestureRecognizer(hover)

        buildSuggestionBar()
        predictionDocumentIdentifier = currentDocumentIdentifier
        buildKeys()
    }

    /// Tears the height constraint down and builds a new one.
    ///
    /// Height lives on the content view, never the root view — a height
    /// constraint on the root fights the system's cached window frame, and
    /// the loser gets re-cached, which is the feedback loop that made the
    /// keyboard grow on every open. Within that rule, replacing the
    /// constraint is the strongest signal available that the size really
    /// changed.
    func rebuildHeightConstraint() {
        heightConstraint?.isActive = false
        let height = trackingView.heightAnchor.constraint(equalToConstant: requestedHeight)
        height.isActive = true
        heightConstraint = height
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // Pointer support (trackpad, Apple Pencil hover, AssistiveTouch
    // pointer devices): moves the same explore highlight touch does, but
    // never commits — lift/click still drives commit via touchLifted.
    @objc func handleHover(_ g: UIHoverGestureRecognizer) {
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
        pendingCorrection = nil
        pendingAutomaticCorrection = nil
        appliedCorrection = nil
        // Reload before buildKeys() below so app-side My Words edits and a
        // fresh field both show up on this appearance, and so a stale
        // in-progress token from a previous field never leaks into a new one.
        isPrivate = Preferences.privateMode(in: store)
        smartGrammar = Preferences.smartGrammar(in: store)
        boardFollowsSentence = Preferences.boardFollowsSentence(in: store)
        // Size is chosen in the app now, so it has to be re-read here —
        // otherwise the change would not land until the extension is next
        // restarted, which from the user's side looks like nothing happened.
        let chosenSize = KeyboardSize.clamped(Preferences.keyboardSize(in: store))
        if chosenSize != size {
            size = chosenSize
            // heightDeficit is a shortfall MEASURED AGAINST ONE PRESET, and
            // it never decays. Carried across a size change it makes every
            // other size wrong, and a shrink wrong in a way that looks like
            // nothing happened at all: the request stays
            // (old preset + deficit) tall, the system keeps the window that
            // tall, and only the drawn board gets smaller — leaving a band
            // of dead space above it. Forget the measurement and take it
            // again for the size actually chosen.
            heightDeficit = 0
            // The self-heal shrinks an oversized window, and it gives up
            // after two tries. Those tries were spent on the old size.
            healAttempts = 0
            // Replace the constraint rather than retune it. Changing
            // `constant` asks the system to revisit a window height it has
            // already cached — the same cache that caused the historic
            // growth bug — and on a size change that request is quietly
            // ignored often enough that the picker looked dead. A new
            // constraint object is a change the layout engine cannot
            // coalesce away.
            rebuildHeightConstraint()
        }
        myWords = (store.array(forKey: "myWords") as? [String]) ?? []
        reloadScreenWords()
        reloadPersonalizationSnapshot()
        promoteSnapshotWords()
        promoteFrequentWords()
        predictionTrieSignature = ""
        typedToken = ""
        boardBackground.backgroundColor = isPrivate ? Palette.privateBoard : Palette.board
        heightConstraint?.constant = requestedHeight
        let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
        predictionDocumentIdentifier = currentDocumentIdentifier
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
        resetTouchIntent()
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
        let documentIdentifier = currentDocumentIdentifier
        if predictionDocumentIdentifier != documentIdentifier {
            completionWords = []
            predictionTrieSignature = ""
            pendingCorrection = nil
            typedTokenTouchEvidence = nil
            resetTouchIntent()
        }
        if !isApplyingCorrection, let correction = appliedCorrection,
           !CorrectionContextGuard.canUndo(
                correction,
                documentIdentifier: documentIdentifier,
                currentSuffix: contextBefore()) {
            appliedCorrection = nil
        }
        predictionDocumentIdentifier = documentIdentifier
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
    func refreshVerbForms() {
        guard smartGrammar, isWordLevel else { return }
        let context = contextBefore()
        guard Grammar.verbForm(after: context) != verbForm
                || Grammar.subject(before: context) != verbSubject
                || SentenceShape.expected(after: context) != boardSlot else { return }
        buildKeys()
    }
}
