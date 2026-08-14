# What the keyboard actually costs in memory

**11 Aug 2026. First real reading: 58.3 MB peak on the simulator, against
a 30–80 MB ceiling. Device figure still outstanding.**

## Why it went unmeasured for so long

`CLAUDE.md` has said "the keyboard extension has a ~30-80MB memory ceiling"
since the project started, and for three months that was a rule people
remembered rather than a number anybody had. Nothing crashed, so nothing
prompted a check.

That is the wrong signal to wait for. Going over the limit does not look
like a crash to the person holding the iPad — iOS kills the extension and
the system keyboard takes its place, so the board vanishes mid-sentence and
comes back as something he cannot use. For a nonverbal person whose only
voice is this board, that is the worst failure mode the project has, and it
would arrive silently, on somebody else's device, under memory pressure we
never reproduced.

## What was built

`Shared/Footprint.swift` — the extension reads its own footprint and keeps
the high-water mark in the App Group. `FootprintCard` in the app's
Diagnostics reads it back and shows it against the ceiling.

Two decisions worth recording:

- **`phys_footprint`, not `resident_size`.** Jetsam measures the former.
  Resident size undercounts compressed pages and IOKit memory, so it gives
  a comfortable answer right up until the kill.
- **The peak, not the current value.** The peak is what gets you killed;
  the average is what makes you think you are fine. It is recorded at the
  end of `layoutKeys`, when every key exists and is placed — the most the
  keyboard ever holds.

So this is not a one-off measurement. Any build, any device, any time:
Setup → Diagnostics → Keyboard memory.

## The reading

| where | peak | against |
|---|---|---|
| iPad Pro 13" simulator, 7 board levels exercised | **58.3 MB** | 30–80 MB |
| Ali's iPad Pro M5 | not yet recorded | — |

Inside the range, past the middle, and well past the ~50 MB worth
designing against — a number comfortably inside the worst case rather than
close to the best one.

**The simulator figure is indicative, not authoritative.** A simulator
extension is a macOS process without iOS memory compression, and typically
reports higher than the device. The device reading requires typing one word
with Typikey on a build carrying `Footprint`; until then this is a warning,
not a verdict.

Reading it back off a device:

```bash
xcrun devicectl device copy from --device <udid> \
  --domain-type appGroupDataContainer \
  --domain-identifier group.com.asadullokh.ch5.typikey \
  --source Library/Preferences/group.com.asadullokh.ch5.typikey.plist \
  --destination /tmp/device.plist --user mobile
```

`keyboardPeakFootprint` is the value, in MB.

On a simulator, without Full Access, the extension writes to its own
sandbox instead of the shared container — the reading is in
`…/Containers/Data/PluginKitPlugin/*/Library/Preferences/com.asadullokh.ch5.typikey.keyboard.plist`.
That is the same silent-fallback behaviour every other app-to-keyboard
setting has, and it is worth knowing before concluding the recording is
broken.

## Where it is probably going, if the device agrees

Not investigated yet, deliberately — optimising against a simulator reading
is the kind of work that feels productive and is not. The candidates, in
the order worth measuring:

1. **Emoji on word cells.** Colour glyphs are image-backed, one per cell,
   44 cells. They arrived as stand-ins for Keiko's line art, which means
   the symbol decision now has a memory budget attached to it and not only
   a licensing one.
2. **`KeyView` instances** — 44 live views, each holding attributed
   strings and layers.
3. **Vocabulary and seeds loaded whole** — `vocabIndex`, `seedBigrams`,
   and the prediction table if one exists.

## What this changes

The ceiling stops being folklore. It is now a number on a screen that a
reviewer can check before merging anything that adds an asset, a cache or a
framework to the extension — and the first thing it says is that the
margin is thinner than anyone assumed.
