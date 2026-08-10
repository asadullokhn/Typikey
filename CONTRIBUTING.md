# Contributing

## Workflow

1. **Never push to `master` directly.** It's protected — all changes go through a pull request.
2. Branch from `master`: `feat/<short-name>` or `fix/<short-name>`.
3. Open a PR into `master`. **Review by Ali (@asadullokhn) is required** — CODEOWNERS enforces this.
4. Merge with **Squash and merge** once approved.

## Before opening a PR

- Build both targets (`Typikey` app + `TypikeyKeyboard` extension) — the build must succeed.
- Actually load the keyboard on a device or simulator and type with it. A keyboard that compiles but doesn't load is not done.
- If you changed `project.yml`, run `xcodegen generate` and commit the regenerated project together with it.

## Never commit

- Signing changes (`DEVELOPMENT_TEAM`, provisioning). Set your own team locally in Xcode's Signing & Capabilities and leave it out of commits.
- `DerivedData/`, `xcuserdata/` (already gitignored).

## Commit style

- Imperative mood, concise, explain the why: "Add word-level delete", not "added stuff".
- No emojis. No `Co-Authored-By` lines.

## Design rules that are not up for grabs

These come from the team's community research — breaking them breaks the product's core promise. If you think one is wrong, raise it in a PR discussion, don't silently change it:

1. **Grid positions are stable.** Never reorder or move existing cells — AAC users build muscle memory of where words live. Adding new words at the end of a category is fine.
2. **Explore-then-commit stays.** Touch-down must never type. Sliding highlights; lifting commits.
3. **The 0.5s double-tap guard stays** (delete, word-delete, clear-all, and the cursor arrows are exempt).
4. **No dead zones** — every point maps to the nearest key.
5. **Full Access requested as of 2026-08-05** (deliberate team decision) — solely for the app-group container. The keyboard must stay fully functional without the grant, and the keyboard makes no network calls, granted or not. Prediction stays on-device.
6. **Prediction lives in the suggestion bar only** — never inside the grid.
7. ~~**Language switching relabels in place.**~~ **Retired 10 Aug 2026**: Malay was removed for the MVP, so there is nothing to switch between. The mechanism survives and still matters — a verb key reading `went` instead of `go` must not move — so relabel in place remains the only way a cell is allowed to change.
8. ~~Malay strings are unverified drafts.~~ **Retired 10 Aug 2026** with the removal. The principle behind it outlives the language: never ship a word into a fixed position that no one who speaks the language has checked. He cannot tell the board it is wrong.
9. **The pinned control column renders identical frames on every level** (asserted by `PinnedFrameTests`). It is one column, on the left — Home, Clear all, word-delete, language. The team's design (2026-08-07) moved Enter, ⌄ and → into the content grid, which is why there is no longer a right-hand pinned column; the surviving guarantee is that the left one never derives its geometry from the content grid's column count.

## Memory budget

Keyboard extensions get roughly 30-80MB before iOS kills them. No heavy assets, no large frameworks, no image libraries in the extension target without discussing it first.
