# CLAUDE.md — rules for Claude Code sessions in this repo

## What this project is

Typikey is a TouchChat-style iPadOS keyboard extension for a specific real person: an AAC user with spastic quadriplegic cerebral palsy whose bottleneck is spatial precision (up to 30 seconds per tap on a standard keyboard), not vocabulary or thinking speed. Read `README.md` before changing anything — every design decision traces to community research, and the reasoning matters more than the code.

## Git rules

- **Never push to `master`.** It is protected. Always work on a branch (`feat/...` or `fix/...`) and open a PR.
- PRs require review from @asadullokhn before merging. Do not merge your own PRs.
- **Never commit signing changes** — `DEVELOPMENT_TEAM` in `project.yml` or anything provisioning-related. Set the team locally in Xcode instead.
- Commit messages: imperative mood, concise, no emojis, **no `Co-Authored-By` lines**.
- Do not force-push. Do not amend published commits.

## Build rules

- `project.yml` is the source of truth; the `.xcodeproj` is generated. After editing `project.yml`, run `xcodegen generate` and commit both together.
- Build both targets before declaring anything done. Then actually run the keyboard on a device/simulator and type with it — including the practice field in the container app.
- The keyboard extension has a ~30-80MB memory ceiling. Keep it lightweight: no heavy dependencies, no image assets in the extension target.

## Design invariants — do not "improve" these away

The full list with reasoning lives in `CONTRIBUTING.md`. The short version:

1. Grid cell positions never move or reorder (muscle memory). New words go at the end.
2. Touch-down never types. Lift-off commits. Sliding is free exploration.
3. Same-key commits within 0.5s are ignored (delete, word-delete, clear-all, and the cursor arrows are exempt).
4. Every point on the keyboard maps to the nearest key — no dead zones.
5. `RequestsOpenAccess` is `true` as of 2026-08-05 (team decision, Ali) to enable the app-group container powering app ↔ keyboard data. Two hard rules survive the flip: the keyboard must remain FULLY functional when Full Access is not granted (never gate typing, prediction, or learning-in-sandbox on the grant), and **no network calls from the keyboard, ever** — granted or not. The shared container is the only thing the permission is for.
6. Prediction appears only in the suggestion bar, never by reordering the grid.
7. ~~Language switching relabels cells in place.~~ **Retired 10 Aug 2026** — Malay was removed for the MVP (team decision). The relabel-in-place mechanism it protected is still load-bearing: verb keys change form with the sentence without moving. If a second language returns, this invariant returns with it.
8. ~~Malay vocabulary is an unverified draft.~~ **Retired 10 Aug 2026** with the removal. The reasoning still binds anything that replaces it: an unverified word in a fixed position is worse than no word, because he cannot tell the board it is wrong.
9. The pinned control column (one column, on the left: Home, Clear all, word-delete, language) renders identical frames on every level — never derive its geometry from the content grid's column count. Enter, ⌄ and → live inside the content grid, per the team's design.

## When unsure

If a change touches any invariant above, or adds a permission, framework, or architectural pattern — stop and say so in the PR description instead of deciding unilaterally. The team reviews design changes together; the research behind them lives in the team's shared vault, not in this repo.
