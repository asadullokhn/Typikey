# Keyboard Extension Startup Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Typikey launch and type reliably when a host temporarily provides no text-document identifier.

**Architecture:** Treat `UITextDocumentProxy.documentIdentifier` as an unreliable external boundary even though the SDK imports it as non-optional. Read it through one Objective-C-safe adapter, keep prediction identity optional, and fail closed for correction application when no identifier is available.

**Tech Stack:** Swift 5.9, UIKit custom keyboard extension, Foundation, XCTest, XCUITest, iPadOS 26.5 Simulator.

## Global Constraints

- Verify the keyboard extension on the active iPad Pro 13-inch (M5) Simulator before running broader test and build gates.
- Preserve typing when `documentIdentifier` is absent; only document-bound prediction reset and correction application may degrade.
- Do not restore direct Swift reads of `UITextDocumentProxy.documentIdentifier`; UIKit can return Objective-C `nil` during `viewDidLoad`, which traps during Swift bridging.
- Automatic and suggested corrections must fail closed when the current document cannot be identified.
- Keep the existing two-edge-column layout, large keyboard footprint, touch behavior, and prediction UI unchanged.
- Do not commit, amend, push, or create a PR.

---

## Approved design

The extension is installed, enabled, and launched by PlugInKit. Its crash report identifies `KeyboardViewController.viewDidLoad()` at the direct `documentIdentifier` read as the faulting frame, with `UUID._unconditionallyBridgeFromObjectiveC` and `SIGTRAP`. The last working implementation did not read this property during startup.

The repair introduces one adapter that invokes the Objective-C getter without forcing a non-optional UUID bridge. Every extension call site consumes the adapter's `UUID?`. Prediction state may use that optional identity; correction creation requires a real UUID, and correction guards reject a missing current UUID.

### Task 1: Protect the document-identity boundary

**Files:**

- Create: `Shared/TextDocumentIdentity.swift`
- Create: `Tests/TextDocumentIdentityTests.swift`
- Modify: `Tests/CorrectionContextGuardTests.swift`
- Modify: `Shared/CorrectionEngine.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `Keyboard/KeyboardLearning.swift`

**Interfaces:**

- Produces: `TextDocumentIdentity.read(from object: AnyObject) -> UUID?`
- Changes: `CorrectionContextGuard.canApply(documentIdentifier: UUID?, ...) -> Bool`
- Changes: `CorrectionContextGuard.canUndo(_:documentIdentifier: UUID?,currentSuffix:) -> Bool`

- [x] Write tests proving a missing Objective-C document identifier returns `nil`, a valid one returns its UUID, and correction guards reject a missing current identifier.
- [x] Run only the new/changed unit tests and confirm RED because the adapter and optional guard contract do not exist.
- [x] Implement the Objective-C-safe adapter and optional fail-closed guard.
- [x] Replace every direct keyboard-extension read of `textDocumentProxy.documentIdentifier` with the adapter.
- [x] Run the focused unit tests and confirm GREEN.

### Task 2: Verify the real keyboard first

**Files:**

- Test: `UITests/PinnedFrameTests.swift`

- [x] Run `PinnedFrameTests/testHomeWordTapInsertsWord` on Simulator `C7232774-55C2-4C36-A7A3-677FD7E98E8E`.
- [x] Confirm the Typikey home grid becomes visible and a word key inserts text into the host field.
- [x] Inspect Simulator logs for a new `TypikeyKeyboard` crash; the run must contain none.

### Task 3: Clean and verify the repaired surface

**Files:**

- Modify only files from Task 1 if cleanup is required.

- [x] Search the keyboard target for remaining direct `textDocumentProxy.documentIdentifier` reads; expected count is zero.
- [x] Run all `TypikeyTests`.
- [x] Run the keyboard layout/theme tools if present and executable.
- [x] Build the `Typikey` scheme in Release for the active Simulator.
- [x] Run `git diff --check` and review the final focused diff without modifying unrelated user changes.

**Gate:** The extension launches without `SIGTRAP`, Typikey is visible, tapping a home word inserts text, all unit tests pass, and Release builds successfully.
