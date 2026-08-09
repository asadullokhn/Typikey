# Typikey

A TouchChat-style iPadOS keyboard extension for people with limited fine motor control. Built by Ali, Artem, and Keiko for Apple Developer Academy Challenge 5, inspired by our community: The Inclusive Pair (Muhammad Sayfullah and Siti Fadillah, Singapore-based AAC advocates).

## The problem

Sayfullah communicates through TouchChat, an AAC (Augmentative and Alternative Communication) app with a large symbol grid. His symbol-grid speech is fluent — 30-45 seconds per sentence. But the moment he needs a word that isn't in his grid, he falls back to the standard on-screen keyboard, where a single mid-word tap can take up to 30 seconds. We watched this happen live during our interview. The bottleneck is spatial precision, not vocabulary or thinking speed: small keys demand an accuracy his hands don't have. That locks him out of most of the digital world — messaging, commenting, posting — because everything there assumes fast, precise typing.

## The idea

A system-wide keyboard (works in any app: Messages, Instagram, Notes) that brings the interface he already trusts — the TouchChat word grid — to every text field on the device. One tap inserts one whole word.

Our competitive research found nobody has built this: TouchChat, Proloquo2Go, Tobii Dynavox, CoughDrop, and Avaz all only compose-and-share from inside their own app. The closest precedent is AssistiveWare's Keeble (an accessible letter keyboard), which proves the architecture is shippable and App-Review-approvable.

## Design decisions, and where each one comes from

Every interaction decision traces to a specific research finding:

| Decision | Source |
|---|---|
| Word grid with category pages, letter keyboard only as fallback | TouchChat's own structure — the interface Sayfullah already has muscle memory for |
| Fitzgerald color key (pronouns yellow, verbs green, nouns orange, social pink) | Standard AAC color convention, used by TouchChat |
| Explore-then-commit: touching down costs nothing, sliding highlights, only lifting the finger commits | VoiceOver keyboard's two-stage typing pattern (accessible-keyboards research) |
| 0.5s double-tap guard: repeat commits of the same key are ignored | Game Accessibility Guidelines debounce recommendation (game-controllers research) |
| No dead zones: every point on the surface maps to the nearest key | The core insight that his problem is precision — there is no "between keys" to miss into |
| Prediction lives in the suggestion bar; grid cells never reorder | Motor planning depends on stable target positions — moving targets destroy AAC fluency |
| Full Access requested, never required | The grant unlocks only the shared app-group container (app-editable data). Typing, prediction, and learning all work ungranted (Guideline 4.4.1); the keyboard makes no network calls either way |
| Design for one person, let it generalize | "We're not trying to design for all of us, we're trying to design for each of us" — Bryce Johnson, Xbox Adaptive Controller co-inventor |

## Features (current state)

- Uniform frame on every level (team design, 2026-08-07): one pinned column on the left — Home, Clear all, word-delete, language — beside a 4×10 content grid. It renders an identical frame regardless of level, so muscle memory for "delete is always over there" survives every navigation. Enter (double-width, row 2), ⌄ and → sit inside the grid at fixed positions rather than in a second pinned column
- Home is the generative board, curated to its 33 cells: every pronoun, the auxiliaries `be do have can will`, the verbs that combine with everything, and the closed classes — `to for with in on`, `and`, `a the my`. A stored phrase says one thing; "I am waiting" is a dead end without `for`, and no amount of prediction fixes that — a preposition has to sit in one known place, one tap away, every time. Core word lists (Banajee et al.; Boenisch & Soto) rank these among the highest-frequency words in anything anyone says, which is why every published core board carries them permanently. The full 54-word Core, and the fixed phrases, are one tap away under Categories
- Three levels deep: the home word board → Categories → a category's words. Letters and numbers are a parallel typing track reached via the abc/123 cells, for words not in the grid
- Category tiles: Recents / Core / People / Actions / Feelings / Food / Places / Art / Web / Chat / Mine — wide double-width tiles, all eleven within the four-row board
- Recents learns his 12 most-used words automatically — his own words included, not just the built-in vocabulary
- Prediction bar above the grid, full width for three suggestions — next-word prediction is an on-device bigram model, seeded with defaults, learning his real word patterns over time. The system globe sits in the pinned column's bottom slot, where iOS keyboards put it
- Phrase completion (iOS 26 devices with Apple Intelligence): the bar offers a short continuation in the user's own vocabulary — tap the phrase to take it all, or ▸ to take one word. Generated entirely on device; on unsupported devices the bar simply shows word prediction as before.
- Keyword capture: words typed letter-by-letter three or more times become candidates in the app's My Words screen — accept one and it joins the keyboard's Mine category. Counts stay in the on-device store, nowhere else.
- My Words: a tremor-friendly editor in the app (big buttons, two-tap remove, no drag-and-drop) feeding the Mine category through the shared container. Requires the Full Access grant to reach the keyboard.
- Pointer hover: a trackpad, Apple Pencil, or AssistiveTouch pointer (joystick) highlights the key it is over before any click — explore-then-commit for pointer users.
- Screen learning (opt-in): the "Learn from my screen" card starts a system screen broadcast (red indicator, user-stoppable any time) that OCRs throttled frames on-device and remembers the words seen; the keyboard then suggests them while replying — names and topic words that no dictionary has. Word counts only, in the shared container; frames are never stored and nothing is ever uploaded.
- Letter keyboard (large-key QWERTY) and numbers layer as fallback, with system spell-checker word completions
- Word-level delete (one tap removes the whole last word)
- Punctuation cells that attach to the preceding word
- Two grid languages: English and Malay (Bahasa Melayu), toggled by the EN/MS key. Language switching relabels cells in place — grid positions never move, so muscle memory survives the switch. Prediction seeds and category names follow the active language. Malay translations are drafts pending verification with Fadillah
- Typing follows the text, not the toggle: letters-level word completions detect the language of what's actually in the field (any language the system spell-checker knows) and complete in it; phrase completion answers in the language the sentence is written in; screen learning OCRs whatever language is on screen. No setting to flip — it just works
- Three keyboard sizes, chosen in the app rather than on the board — a grid slot is a word, and size is set once and then never again. The board is always four rows of ten, exactly as designed; the size changes how big each key is, not how many there are. Large is 640pt, giving rows of roughly 146pt — the easiest targets this board has had
- Dismiss key, like Apple's iPad keyboard
- Field-type intent mapping: the keyboard opens on the level that matches the focused field (e.g. a search field opens on letters, a numeric field opens on numbers) — applied once per field, never mid-typing; manual navigation always wins afterward
- Key-commit feedback: three distinct haptics, deliberately strong, because the iPad sits on a stand and is driven by joystick — a heavy impulse when a key commits, a soft tick when the finger slides onto a different key (so the board can be read by feel), and a warning pattern when Clear all arms. Haptics need Full Access; without it iOS drops them silently, so nothing depends on them
- Grammar support, in both the forms the AAC products offer it:
  - **Context-driven** — verb forms follow the sentence. After "I am" the `go` key reads `going`, after "he" it reads `goes`, after "have" it reads `gone`, and `be` reads `am` / `is` / `are` from the subject. Relabelled in place, never moved
  - **Tense from the sentence's own time words** — `yesterday` puts every verb key in the simple past (`go` → `went`, `be` → `was`/`were`), `tomorrow` and `will` put them in the future. No tense key: the board carries the design's controls and no others, so tense is read from words the user was going to tap anyway. That is also how English works — the verb ending is ambiguous and the adverb is what places the sentence. Scoped to the current sentence, so a full stop clears it
  - An auxiliary already in the text always wins over the tense key — "I will went" is not a sentence anyone wants
  - English only. Malay marks tense with particles rather than by inflecting, so the tense slot is reserved but left empty there, which keeps every word cell on identical coordinates in both languages. Same when Smart Grammar is switched off in the app
- Responsive layout: word boards drop to a compact 5-column content grid when the system narrows the keyboard (floating, Split View, Slide Over); the letters and numbers levels keep all 10 columns so no character goes missing. The pinned column never changes width or position, at any width
- iPhone: the same keyboard, smaller — phone-sized height presets, and compact word boards run 8 content rows so every cell stays reachable (the pinned column keeps its 4-row frame)
- Auto-filing (Gilbert build): a word added to My Words that is recognizably a person, place, or action ALSO appears at the end of that category's page, in Mine's pink so it always reads as "his word" — the board configures itself, visibly, so nobody hunts for a word. Detection is on-device NLTagger; ambiguous words stay Mine-only; the My Words screen says where each word was filed
- All learning (usage counts, bigrams) stays on-device: in the shared app-group container when Full Access is granted (so the app can read it), in the keyboard's own sandbox when not — never on a network

## Project structure

```
Typikey/
  project.yml                      xcodegen spec — the source of truth for the project
  App/TypikeyApp.swift             container app: setup instructions + practice text field
  Keyboard/KeyboardViewController.swift   the entire keyboard extension
  Typikey.xcodeproj                generated — regenerate with `xcodegen generate`
```

## Build and run

Requirements: Xcode 26+, an iPad (or simulator), and a signing team.

1. Clone, then open `Typikey.xcodeproj` (or run `xcodegen generate` first if you've changed `project.yml` — `brew install xcodegen` if needed).
2. **Change `DEVELOPMENT_TEAM` in `project.yml` to your own team ID** (currently Ali's), regenerate, or just set your team in Xcode's Signing & Capabilities for both targets.
3. Build and run the `Typikey` scheme on your device.
4. On the iPad: Settings → General → Keyboard → Keyboards → Add New Keyboard → Typikey.
5. Open any app with a text field (or the Typikey app's practice field), hold the globe key, choose Typikey.

First run on a new device needs Developer Mode enabled (Settings → Privacy & Security → Developer Mode) and the device registered to your team — Xcode handles that automatically on first install.

## Testing

- Manual: build to a device, enable the keyboard, and use the practice field in the app. The regression checklist that matters: open/close/reopen the keyboard several times, rotate both ways, and confirm the height never grows (this was a real bug — see the git history on `fix/rotation-height`).
- Automated: `UITests/KeyboardHeightTests.swift` contains a scripted version of that exact checklist with height assertions. It is currently prefixed `todo_` (skipped) because reliably making a third-party keyboard the *active* keyboard inside a simulator is unsolved — the file documents what was tried. Run it by renaming the method to `test...` and running the Typikey scheme's tests against a **freshly erased** simulator.

## Known limitations / not yet decided

- Malay vocabulary was drafted by the team, not by a native-speaking AAC user — verify every word with Fadillah before testing with Sayfullah. Singaporean Malay has colloquial forms a dictionary translation misses.
- Vocabulary is hardcoded. The App Group + Full Access groundwork for app-edited vocabulary landed 2026-08-05; the editing UI itself does not exist yet.
- No speech output. Audio in keyboard extensions is gated behind Full Access (this is exactly what Keeble does: on-device prediction free, speech gated). Same deliberate decision needed.
- Apple Foundation Models sentence completion is on the roadmap, deliberately not in the MVP. Open research question: extensions may be sandboxed away from the on-device model — needs a 5-minute empirical test (`SystemLanguageModel.availability` from inside the extension) before that feature is ever promised.
- True detachable floating (drag the keyboard anywhere) is not possible for keyboard extensions — the system owns that window. Our responsive layout handles whatever size the system gives us instead.
- Keyboard extensions have a tight memory ceiling (~30-80MB per our research). Current build is nowhere near it, but a large symbol library would be — test on older hardware before adding image assets.

## The team

- Ali — code
- Artem — code / PM, AI prediction research
- Keiko — design, accessible-interface research

Challenge context, research notes, and interview findings live in the team's Obsidian vault (`Projects/ADAP/CH5/`).
