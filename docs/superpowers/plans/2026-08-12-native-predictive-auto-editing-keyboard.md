# Native Predictive and Auto-Editing AAC Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a privacy-preserving, on-device prediction and guarded auto-editing engine for Typikey that reduces AAC tap cost without moving established grid keys or making typing depend on Foundation Models, Full Access, the containing app, or a network connection.

**Architecture:** Keystroke-critical work runs in the keyboard extension through deterministic prefix, n-gram, personal-vocabulary, field-intent, touch-distance, and edit-distance scoring. On eligible iPadOS 26 devices, Apple's system model asynchronously enriches the suggestion bar and verifies uncertain corrections; it never blocks input. The containing app requests permissions, curates personal context while active, and atomically publishes a compact versioned snapshot through the App Group.

**Tech Stack:** Swift 5.9, UIKit custom keyboard extension, SwiftUI containing app, `UITextDocumentProxy`, NaturalLanguage, Foundation Models on iPadOS 26+, App Groups, XCTest/XCUITest, XcodeGen, and the existing `Tools/tapcost` corpus harness.

## Global Constraints

- Keep the deployment target at iPadOS/iOS 18.0. Foundation Models is an optional iPadOS 26+ enhancement.
- The keyboard must insert text and produce deterministic suggestions when Foundation Models is unavailable, Apple Intelligence is disabled, Full Access is disabled, or the containing app is suspended or terminated.
- The keyboard makes no network calls and never stores or logs raw composed messages.
- Do not implement a live request/response bridge to the containing app. iPadOS normally suspends background apps; App Group data is snapshot synchronization, not a live inference service.
- Darwin notifications, if retained, only invalidate an in-memory cache while both processes are alive. They are neither transport nor a wake guarantee.
- Keep every established board key at its configured position. Predictions appear only in the suggestion bar; automatic learning never scrambles the grid.
- Continue to commit text through `UITextDocumentProxy`. Do not promise rich highlighting or editing controls inside another app's view.
- Automatic replacement remains disabled until correction precision is at least 95% on an untouched holdout set. Before that gate, every candidate is suggestion-only.
- Deterministic character-to-candidate latency target: at most 50 ms at P95 on supported physical iPads.
- Empty-field candidate latency target: at most 100 ms at P95 from cached/trie data.
- Reverse deterministic evaluation target: at most 500 ms at P95, with 100 ms as the engineering target.
- Keyboard physical-footprint target: at most 30 MB during the endurance scenario. The measured footprint and jetsam-free result are release gates; no undocumented iPadOS limit is treated as contractual.
- Foundation Models response time is measured separately and never included in the 50 ms deterministic SLA. Cancel an enrichment request after 2 seconds.
- Preserve the existing lift-off commit, nearest-key/no-dead-zone behavior, debounce exemptions, private mode, fixed edge controls, language behavior, and keyboard height machinery.
- No commits, amend, push, or PR operations are part of this plan; the user owns git operations.

---

## Platform decisions and corrections

1. Foundation Models is available from iOS/iPadOS 26, not iOS 18. Runtime and compile-time guards remain mandatory.
2. `LanguageModelSession.prewarm(promptPrefix:)` may reduce first-generation latency, but Apple documents response generation as potentially taking seconds. Trie and cached prediction provide the immediate result.
3. Foundation Models does not expose token logits, perplexity, or language-model surprisal. The deterministic engine uses normalized n-gram/context likelihood. A model may verify borderline candidates through structured generation, but that score is not called perplexity.
4. The containing app cannot continuously service keyboard requests while the user types in Messages, Mail, Safari, or another host. App-side work is foreground or opportunistic curation followed by snapshot publication.
5. A custom keyboard can insert/delete unattributed text and manipulate the insertion point through `UITextDocumentProxy`; it cannot draw an inline correction highlight in a host application's text view. A keyboard-owned Undo chip is the correction feedback mechanism.
6. Model size, quantization, ANE scheduling, and exact power consumption are controlled by Apple. They are observed during profiling, not application-level deliverables.

Apple references:

- [Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Generating content with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession)
- [Handling text interactions in custom keyboards](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards)
- [Custom keyboard capabilities and limitations](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)
- [Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)

## Existing implementation to preserve

- `Keyboard/CompletionEngine.swift` already guards iPadOS 26 availability, reuses a `LanguageModelSession`, cancels stale work, and degrades after repeated failures.
- `Keyboard/KeyboardLearning.swift` already combines live on-device completion, learned bigrams, screen words, personal words, and `UITextChecker` completions.
- `Keyboard/TrackingView.swift` and `Keyboard/KeyboardInput.swift` already expose raw touch locations, lift-off commit, and nearest-key selection.
- `Shared/Footprint.swift` already records the extension's physical footprint and high-water mark.
- `Tools/tapcost` already provides the tap-cost regression baseline and evaluates deterministic learned-bigram tables.
- `docs/experiments/2026-08-10-app-side-model.md` already records why live app-side inference is infeasible and why general-model word tables performed worse than the deterministic baseline.

## Planned file map

### Create

- `Shared/PredictionTypes.swift` — immutable request, candidate, source, and result types shared by deterministic and model-assisted paths.
- `Shared/PrefixTrie.swift` — bounded, case-insensitive first-character and partial-word lookup.
- `Shared/PredictionRanker.swift` — deterministic score normalization, source merging, deduplication, and Top-3 selection.
- `Shared/TouchIntentFilter.swift` — timestamped touch samples, tremor smoothing, centroid-distance likelihood, and per-key calibration state.
- `Shared/DoubleMetaphone.swift` — bounded dependency-free English phonetic keys for correction candidates.
- `Shared/CorrectionEngine.swift` — candidate generation and unified suggestion/replace/ignore decision.
- `Shared/PersonalizationSnapshot.swift` — versioned, privacy-minimized data published by the app and read by the keyboard.
- `Keyboard/FieldIntent.swift` — adapter from `UITextInputTraits` to the shared prediction profile.
- `App/PersonalizationService.swift` — permission-gated Calendar/Location/user-vocabulary curation and atomic snapshot publication.
- `Tests/PredictionRankerTests.swift`
- `Tests/PrefixTrieTests.swift`
- `Tests/TouchIntentFilterTests.swift`
- `Tests/CorrectionEngineTests.swift`
- `Tests/PersonalizationSnapshotTests.swift`

### Modify

- `project.yml` and generated `Typikey.xcodeproj` — add a `TypikeyTests` unit-test target and register new sources through XcodeGen.
- `Keyboard/KeyboardViewController.swift` — own coordinator state, correction Undo state, cache reloads, and lifecycle cancellation.
- `Keyboard/KeyboardLearning.swift` — replace ad hoc suggestion assembly with one ranked request/result path.
- `Keyboard/KeyboardInput.swift` — send committed-word and touch evidence to correction evaluation; perform guarded replacement and Undo.
- `Keyboard/TrackingView.swift` — forward timestamped began/moved/ended samples rather than only the latest point.
- `Keyboard/CompletionEngine.swift` — add prewarming, structured output, field profiles, and observable latency/failure results without blocking deterministic suggestions.
- `App/EngineStatus.swift` — physical-device cold, prewarmed, and warm probes with no prompt content retained.
- `App/SettingsCard.swift` or the existing relevant setup card — personalization consent, correction mode, and data deletion controls.
- `Tools/tapcost/main.swift` — Top-3 hit rate, correction precision/recall, false-replacement count, and source attribution.
- Existing UITest files — regression coverage for field switching, fixed layout, correction Undo, private mode, and degraded model behavior.

---

### Task 1: Establish typed contracts, a unit-test target, and baselines

**Files:**

- Create: `Shared/PredictionTypes.swift`
- Create: `Tests/PredictionRankerTests.swift`
- Modify: `project.yml`
- Modify: `Typikey.xcodeproj` through `xcodegen generate`
- Modify: `Tools/tapcost/main.swift`

**Interfaces:**

```swift
enum PredictionSource: String, Codable, Sendable {
    case prefix, personal, screen, learnedNGram, seedNGram, foundationModel
}

enum FieldProfile: String, Codable, Sendable {
    case conversational, search, email, url, generic
}

struct PredictionRequest: Sendable {
    let contextBefore: String
    let partialWord: String
    let sentenceStart: Bool
    let fieldProfile: FieldProfile
    let maximumCandidates: Int
}

struct PredictionCandidate: Equatable, Sendable {
    let text: String
    let score: Double
    let source: PredictionSource
}

struct PredictionResult: Equatable, Sendable {
    let candidates: [PredictionCandidate]
    let generatedAt: ContinuousClock.Instant
}
```

- [ ] Add `TypikeyTests` as a unit-test bundle depending on the app target so tests can use `@testable import Typikey` for Shared sources.
- [ ] Add a failing test proving candidate identity is case-insensitive while returned casing is preserved.
- [ ] Add a failing test proving a result never contains more than three candidates for the production request.
- [ ] Implement only the shared types needed to pass those tests.
- [ ] Extend `Tools/tapcost` output with baseline tap count, Top-3 hit rate, phrase hits, spelled words, and source attribution. Preserve current output when the new metrics are not requested.
- [ ] Record the pre-refactor corpus output in the task report; do not hard-code a new target until representative personal sentences are available.
- [ ] Run:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild test -project Typikey.xcodeproj -scheme Typikey \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -only-testing:TypikeyTests
./Tools/tapcost/run.sh --file Tools/tapcost/corpus-200.txt
```

**Gate:** Existing behavior and tap cost remain unchanged; the new unit-test target passes.

---

### Task 2: Build immediate prefix and deterministic Top-3 ranking

**Files:**

- Create: `Shared/PrefixTrie.swift`
- Create: `Shared/PredictionRanker.swift`
- Create: `Tests/PrefixTrieTests.swift`
- Expand: `Tests/PredictionRankerTests.swift`

**Interfaces:**

```swift
struct PrefixTrie: Sendable {
    init(words: [(text: String, frequency: Int)])
    func completions(for prefix: String, limit: Int) -> [String]
}

struct PredictionRanker: Sendable {
    func rank(_ candidates: [PredictionCandidate], limit: Int) -> [PredictionCandidate]
}
```

- [ ] Test empty-prefix opening candidates, one-character lookup, mixed-case lookup, apostrophes, duplicate vocabulary, frequency ordering, and hard result limits.
- [ ] Implement a bounded trie whose nodes store only the best completion indexes needed by the suggestion bar; do not retain duplicate strings at each node.
- [ ] Test source-weight merging, exact-text deduplication, stable tie-breaking, casing preservation, non-finite score rejection, and Top-3 truncation.
- [ ] Implement score normalization per source before weighted merging. Keep weights in one static configuration value so corpus calibration changes data rather than branching logic.
- [ ] Benchmark 1,000 first-character and partial-word lookups on a representative release vocabulary.

**Gate:** Prefix and rank operations finish below 10 ms at P95 in a release build; all ranking output is deterministic for identical input.

---

### Task 3: Integrate field intent and the deterministic coordinator

**Files:**

- Create: `Keyboard/FieldIntent.swift`
- Modify: `Keyboard/KeyboardLearning.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `UITests/PinnedFrameTests.swift`
- Modify: `UITests/PrivateModeTests.swift`

**Interfaces:**

```swift
extension FieldProfile {
    init(traits: any UITextInputTraits)
}

@MainActor
func deterministicPredictions(for request: PredictionRequest) -> PredictionResult
```

- [ ] Add field-profile mapping tests through a lightweight test traits object: `.URL` maps to `.url`, `.emailAddress` to `.email`, `.webSearch` to `.search`, `.send` to `.conversational`, and everything unsupported to `.generic`.
- [ ] Make `updateSuggestions()` build one `PredictionRequest` from `documentContextBeforeInput`, partial word, sentence state, and current traits.
- [ ] Merge trie matches, personal words, fresh screen words, learned n-grams, shipped seeds, and enabled cached-model data through `PredictionRanker`.
- [ ] Preserve the current letters-level `UITextChecker` fallback after local personalized matches.
- [ ] Rebuild prediction state when the field/document identifier changes so context and partial words never leak between host fields.
- [ ] Confirm private mode excludes learned, screen, cached-model, and personalized sources while shipped vocabulary continues working.
- [ ] Add UITest assertions that the suggestion toolbar changes by field type without changing grid frames or hiding required edge controls.

**Gate:** Every keystroke renders deterministic candidates within 50 ms P95, and all existing fixed-layout/private-mode UI tests pass.

---

### Task 4: Make Foundation Models a bounded asynchronous enricher

**Files:**

- Modify: `Keyboard/CompletionEngine.swift`
- Modify: `Keyboard/KeyboardLearning.swift`
- Modify: `App/EngineStatus.swift`
- Modify: `UITests/PinnedFrameTests.swift`

**Interfaces:**

```swift
@available(iOS 26.0, *)
@Generable
struct ModelSuggestion {
    @Guide(description: "One to three short continuations, best first", .maximumCount(3))
    var candidates: [String]
}

enum CompletionOutcome: Equatable {
    case available(words: [String], latency: Duration)
    case unavailable
    case timedOut
    case failed
    case superseded
}
```

- [ ] Add an injectable response closure around session generation so cancellation, stale result rejection, timeouts, and fallback can be unit-tested without invoking the model.
- [ ] Prewarm the lazily created session with a short prompt prefix selected by `FieldProfile`.
- [ ] Replace raw string parsing with guided generation capped at three candidates and a small maximum response-token limit.
- [ ] Keep one request in flight. Cancel it when input, document identifier, field profile, keyboard level, or private-mode state changes.
- [ ] Render deterministic candidates immediately, then merge a still-current model result through the same ranker. Never clear a good deterministic bar while waiting.
- [ ] Add a separate structured correction-verification request that receives the original word, at most five deterministic alternatives, and a bounded surrounding-context snippet. Its result is advisory and never performs editing itself.
- [ ] Degrade for the keyboard session after repeated hard failures, preserving the current fallback behavior.
- [ ] Expand the app probe to report cold, prewarmed-first, and warm latency plus availability reason. Store only numeric results and timestamps.
- [ ] Verify on the physical target iPads in conversational, search, URL, and unsupported-language fields.

**Gate:** Foundation Models unavailability, delay, error, or stale completion is invisible to typing; the simulator degraded-path test stays green.

---

### Task 5: Add touch-intent evidence without changing commit behavior

**Files:**

- Create: `Shared/TouchIntentFilter.swift`
- Create: `Tests/TouchIntentFilterTests.swift`
- Modify: `Keyboard/TrackingView.swift`
- Modify: `Keyboard/KeyboardInput.swift`

**Interfaces:**

```swift
struct TouchSample: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case began, moved, ended, cancelled
    }

    let point: CGPoint
    let timestamp: TimeInterval
    let phase: Phase
}

struct TouchEvidence: Equatable, Sendable {
    let filteredPoint: CGPoint
    let intendedKeyIndex: Int
    let neighborLikelihoods: [Int: Double]
}

struct TouchIntentFilter: Sendable {
    mutating func consume(_ sample: TouchSample, keyFrames: [CGRect]) -> TouchEvidence?
    mutating func reset()
}
```

- [ ] Test stationary taps, symmetric tremor around one centroid, a deliberate slide to a new key, rotation/frame replacement, cancellation, and out-of-order timestamps.
- [ ] Forward touch began/moved/ended/cancelled samples with timestamps from `TrackingView`.
- [ ] Implement a lightweight constant-velocity filter and normalized Gaussian distance to the selected key and immediate neighboring key centroids.
- [ ] Preserve the existing visible highlight and nearest-key lift-off commit as the authoritative output. Touch evidence is recorded in memory only for correction scoring.
- [ ] Clear all samples after commit, cancellation, keyboard rebuild, rotation, or document switch.
- [ ] Replay representative tremor traces and compare wrong-key rate and commit latency against the unfiltered baseline.

**Gate:** Touch processing adds less than 5 ms P95, introduces no missed commits, and measurably improves or equals selection accuracy. If accuracy worsens, ship centroid evidence without smoothing.

---

### Task 6: Implement reverse correction in suggestion-only mode

**Files:**

- Create: `Shared/CorrectionEngine.swift`
- Create: `Shared/DoubleMetaphone.swift`
- Create: `Tests/CorrectionEngineTests.swift`
- Modify: `Keyboard/KeyboardInput.swift`
- Modify: `Keyboard/KeyboardLearning.swift`
- Modify: `Tools/tapcost/main.swift`

**Interfaces:**

```swift
struct CorrectionFeatures: Equatable, Sendable {
    let spatial: Double
    let language: Double
    let editSimilarity: Double
    let phonetic: Double
    let personalFrequency: Double
}

enum CorrectionDecision: Equatable, Sendable {
    case ignore
    case suggest(original: String, replacement: String, confidence: Double)
    case replace(original: String, replacement: String, confidence: Double)
}

struct CorrectionEngine: Sendable {
    func evaluate(
        committedWord: String,
        contextBeforeWord: String,
        contextAfterWord: String,
        touch: TouchEvidence?,
        fieldProfile: FieldProfile
    ) -> CorrectionDecision
}
```

- [ ] Generate at most 64 candidates from adjacent-key substitutions, Damerau-Levenshtein distance at most two, `UITextChecker`, user vocabulary, and a dependency-free English Double Metaphone encoder. Disable the phonetic signal for non-English input. Do not scan an unbounded dictionary per commit.
- [ ] Normalize spatial, n-gram context, edit similarity, phonetic equivalence, and personal frequency into `[0, 1]`.
- [ ] Apply one sigmoid scorer with versioned weights and thresholds loaded as static local configuration.
- [ ] Set the initial suggestion threshold to 0.50 and replacement threshold to 0.82. Keep replacement disabled in this task while the corpus harness searches feature weights and thresholds in the approved 0.80–0.85 replacement range.
- [ ] Force `.ignore` for URL, email, secure/unsupported, number-like, all-caps acronym, explicit personal-word, and ambiguous proper-name cases.
- [ ] Keep all decisions suggestion-only regardless of confidence in this task. Tapping the correction chip replaces only the committed token through `UITextDocumentProxy`.
- [ ] For deterministic confidence from 0.50 through 0.82, request asynchronous Foundation Models verification when available. Merge a still-current affirmative review into suggestion ranking only; timeout, refusal, stale context, and unavailable model retain the deterministic decision.
- [ ] Extend the corpus harness with labeled typo cases and report precision, recall, false replacements, and feature-source attribution.

**Gate:** Suggestion precision reaches at least 95% on the holdout corpus with zero automatic replacements.

---

### Task 7: Add guarded automatic replacement and Undo

**Files:**

- Modify: `Shared/CorrectionEngine.swift`
- Modify: `Keyboard/KeyboardInput.swift`
- Modify: `Keyboard/KeyboardLearning.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `UITests/RealSentencesTests.swift`
- Modify: `UITests/PrivateModeTests.swift`

**Interfaces:**

```swift
struct AppliedCorrection: Equatable, Sendable {
    let original: String
    let replacement: String
    let documentIdentifier: UUID
    let expectedContextSuffix: String
}
```

- [ ] Enable `.replace` only for scorer configurations that achieved at least 95% precision on untouched holdout data and pass all protected-field rules.
- [ ] Before deleting, verify that `documentContextBeforeInput` still ends with the exact committed word and that the document identifier is unchanged.
- [ ] Replace through bounded `deleteBackward()` calls followed by `insertText()`. Abort without mutation if the proxy context differs.
- [ ] Put the original word in the first suggestion chip as Undo immediately after replacement.
- [ ] Undo only when the document identifier and expected suffix still match. Otherwise dismiss the Undo state without editing.
- [ ] Clear Undo on cursor movement, field switch, external text change, new sentence, keyboard dismissal, or private-mode transition.
- [ ] Add UI tests for auto-replacement, Undo, stale Undo rejection, punctuation preservation, and no replacement in URL/email fields.

**Gate:** Automatic correction precision remains at least 95%, no protected field is modified, and every applied correction is immediately reversible from the keyboard.

---

### Task 8: Publish privacy-minimized personalization snapshots

**Files:**

- Create: `Shared/PersonalizationSnapshot.swift`
- Create: `Tests/PersonalizationSnapshotTests.swift`
- Create: `App/PersonalizationService.swift`
- Modify: `App/SettingsCard.swift` or the existing relevant setup card
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `Keyboard/KeyboardLearning.swift`

**Interfaces:**

```swift
struct PersonalizationSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1
    let version: Int
    let generatedAt: Date
    let words: [WeightedWord]
    let phrases: [WeightedPhrase]
    let blockedWords: [String]
}

struct WeightedWord: Codable, Equatable, Sendable {
    let text: String
    let weight: Double
}

struct WeightedPhrase: Codable, Equatable, Sendable {
    let text: String
    let weight: Double
}
```

- [ ] Add decoding tests proving current snapshots load, version 0 migrates, unknown-newer/truncated/oversized snapshots are rejected, and snapshots older than 30 days are ignored.
- [ ] Require explicit app-side consent independently for Calendar and Location. Never request those permissions from the keyboard extension.
- [ ] Convert permitted data to minimal weighted tokens: selected event titles/contact names, coarse current-place labels, user-approved words, and local usage frequencies. Exclude coordinates, full event bodies, attendees, full messages, and historical location trails.
- [ ] Bound each snapshot to 512 words, 128 phrases, 64 characters per word, 240 characters per phrase, 256 KB encoded, and 30 days of usable age before publication.
- [ ] Write a temporary file in the App Group, close it, then atomically replace the previous snapshot. Keep the previous valid snapshot if generation or encoding fails.
- [ ] Reload on keyboard appearance and safe lifecycle boundaries; never read the App Group on every touch.
- [ ] Append newly promoted words to the dictionary and suggestion corpus without moving established grid cells.
- [ ] Add app controls to inspect, remove, block, regenerate, and delete all personalization data.

**Gate:** Personalization improves or equals holdout tap cost, the encoded snapshot stays within its fixed size bound, deletion removes all app-published personal data, and the keyboard behaves normally without Full Access.

---

### Task 9: Release hardening and SLA verification

**Files:**

- Modify: `App/EngineStatus.swift`
- Modify: `App/FootprintCard.swift`
- Modify: relevant existing UITest suites
- Add experiment results under `docs/experiments/` only for measurements actually performed

- [ ] Run the complete unit and UI suites on the supported simulator.
- [ ] Run deterministic latency benchmarks in Release configuration on the slowest supported physical iPad and an Apple Intelligence-capable iPad.
- [ ] Run a prolonged typing, rotation, field-switching, model-timeout, and personalization-reload endurance scenario while recording `phys_footprint` peak and thermal state.
- [ ] Verify VoiceOver labels, Switch Control traversal, target sizes, contrast, reduced motion, and lift-off behavior.
- [ ] Verify model unavailable reasons: ineligible device, Apple Intelligence disabled, model not ready, unsupported language, timeout, cancellation, and concurrent-request prevention.
- [ ] Compare deterministic-only and model-enriched Top-3 accuracy, tap cost, and response latency. Ship model enrichment only where it improves user outcomes without destabilizing the extension.
- [ ] Re-run correction calibration on the frozen holdout set and record precision, recall, false replacements, and Undo rate.
- [ ] Confirm no raw context, prompt text, touch trace, calendar detail, or location coordinate appears in logs, analytics, crash metadata added by this work, or the App Group payload.

Run the standard verification command:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild test -project Typikey.xcodeproj -scheme Typikey \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
./Tools/tapcost/run.sh --file Tools/tapcost/corpus-200.txt
```

**Release gate:** All tests pass; Top-3 accuracy is at least 72% on representative holdout data; deterministic P95 latency is at most 50 ms; empty-field P95 is at most 100 ms; reverse analysis P95 is at most 500 ms; auto-edit precision is at least 95%; physical footprint stays at or below the 30 MB project target; no jetsam or serious/critical thermal state occurs; fixed key positions remain unchanged.

## Explicitly out of scope

- Bundling Qwen, Llama, or another open-weights model in the keyboard extension.
- Supporting a bundled Core ML fallback until physical-device benchmarks establish a product need and a memory-feasible deployment topology.
- Continuous containing-app inference or third-party XPC-style services.
- Network inference from the keyboard.
- Claiming token perplexity, raw logits, or embeddings from Foundation Models.
- Visual correction highlighting inside the host application's text view.
- Inline ghost text in the host application's text view; v1 presents completion only in the keyboard-owned suggestion toolbar.
- Guaranteed Apple model parameter count, quantization, ANE routing, wattage, or thermal behavior.
- SQLite, Core Data, vector databases, or memory-mapped IPC unless compact atomic snapshot benchmarks fail the stated latency or size requirements.
- Dynamic grid reordering, automatic replacement of user-dictionary words, or irreversible corrections.

## Delivery sequence

1. Tasks 1–3 deliver a complete deterministic forward-prediction upgrade and can ship independently.
2. Task 4 adds optional iPadOS 26 enrichment without changing the fallback contract.
3. Tasks 5–6 deliver measurable reverse-correction suggestions without automatic editing risk.
4. Task 7 is enabled only after the precision gate is met.
5. Task 8 adds opt-in personal context without placing permissions or sensitive source data in the extension.
6. Task 9 is required before release of any automatic correction behavior.
