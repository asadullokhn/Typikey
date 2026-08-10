# Would a model on the app beat the keyboard's trigrams?

**10 Aug 2026. Answer: no, not this way — and the measurement is what
told us, twice, after the output looked fine.**

## The question

Ali asked whether Typikey could run a custom model instead of leaning on
Apple Intelligence, and then — correctly — whether it could run in the app
rather than in the keyboard.

The second question has a hard answer. A keyboard extension gets roughly
30–80MB before iOS kills it, which rules out shipping any real model
inside it: a 0.5B model at 4-bit is ~350MB. Apple's own on-device model is
the cheap option precisely because it runs out-of-process, in a system
daemon, and costs the extension nothing.

Running a model in the app is possible, but **not live**. The keyboard and
the app are separate processes, and while he is typing in Messages the app
is suspended or dead. A keyboard cannot wake it: `UIApplication.shared`
does not exist in an extension, iOS has no third-party XPC, and a
suspended process does not receive Darwin notifications. So the only
architecture available is **precompute**: the app runs the model when it
is awake, writes a compact table to the App Group, and the keyboard reads
it as pure lookup.

That is worth building only if the table beats what the keyboard already
does. This experiment measured that before any of it was built.

## What was built to answer it

- **`Tools/predict-table/`** — asks the on-device model, for ~90 anchor
  words, which words tend to follow. Anchors are verbs, pronouns,
  function words and question words, because the board's spare cells and
  its suggestion bar both key off the last meaningful word. Asking about
  `banana` spends a model call on a sentence nobody writes.
- **`Tools/tapcost --model-table`** — loads a generated table into
  `learning.bigrams`, which is *the same field the keyboard already reads
  through the App Group*. Deliberately no new plumbing: if a table were
  worth shipping, shipping it would be a write, not an architecture. So
  the measurement measures the thing we would actually build.
- **`--model-weight`** — see round 3.

Apple's on-device model reports `.available` on the development Mac
(macOS 26.5.2), which is what made the whole experiment runnable offline
in minutes instead of on-device over days.

**Baseline to beat: 1847 taps** for the 200-sentence corpus (921 words).

## Round 1 — the model made it worse

**1897 taps. 50 worse than baseline. Spelled words 30 → 32.**

The prompt pasted all ~400 vocabulary words in and asked the model to
choose among them. It replied with the first few words alphabetically:

```
''      ->  at, and, be, because, about
'i'     ->  i, and, the
'eat'   ->  and, eat, but, the
'the'   ->  and, the, of, to, in
```

A 400-item list was most of the prompt, so list order became the strongest
signal in it. `eat` → `and, eat, but` is not a prediction, it is an echo.
Three anchors also blew the 4096-token context window for the same reason.

This is the failure worth recording, because **it does not look like a
failure in a spot check**. `eat → eat` reads as a harmless oddity. Only the
tap count showed it was actively costing him taps.

## Round 2 — ask properly, filter afterwards

The vocabulary came out of the prompt entirely. The model is asked what
follows the word in English; the answer is filtered against the vocabulary
afterwards. Constraining the output is our job, not the prompt's.

Better, and genuinely right in places:

```
'drink'  ->  water, juice, tea
'go'     ->  go, home, stop, please, help
'eat'    ->  eat, drink, sleep, you
'i'      ->  hello, friend, teacher
```

**1879 taps. Still 32 worse than baseline.**

`drink → water, juice, tea` is a real prediction. `i → hello, friend,
teacher` is topic association, not continuation — the model answers "what
is related to this word" more readily than "what follows it".

## Round 3 — was the comparison even fair?

It was not. `bigramScores` multiplies learned pairs by ten, so a table
loaded into that field does not add to the shipped seeds, it drowns them.
The test was measuring "is the model better than everything else put
together", not "does the model know anything".

`--model-weight` separates those. Sweeping it:

| model weight | taps |
|---|---|
| none (baseline) | **1847** |
| 0.1 | 1849 |
| 0.3 | 1865 |
| 1.0 | 1879 |

Monotonic. The model's contribution is worth *less than zero* at every
weight, and the best it manages is to approach baseline as its influence
approaches nothing. There is no setting at which it helps.

## Why — the informative part

Comparing the generated table against the hand-written `seedBigrams`:

- **18 of 83 anchors are ones the seeds already cover.** The model agrees
  with the seeds on 4 of those — and where it agrees, it agrees exactly:
  `drink → water, juice, tea` is character-for-character the shipped seed.
- **65 anchors are the model's own contribution**, and those are what
  moved the number the wrong way.

So the model reproduces the hand-tuned data where that data exists, and
adds noise where it does not. It is confirming what we already knew and
guessing at the rest.

That is not surprising on reflection. The task is next-word prediction
over a ~400-word core vocabulary in telegraphic AAC sentences. A general
model has never seen how *this* person writes, and "communication board
English" is not the English it was trained on. The seeds encode something
the model does not have: what an AAC user actually types.

## Recommendation

**Do not build the app-side model pipeline yet.** The architecture is
sound and the tooling now exists, but the thing it would carry is worse
than what ships today.

What the remaining 30 spelled words actually need is not intelligence:

- plurals (`dragons`, `ideas`, `days`, `videos`)
- comparatives (`easier`, `louder`, `faster`, `shorter`)
- inverted questions (`are`, `is`, `was`) — already repaired by the `?` key

Those are grammar rules, and rules are cheap, deterministic, testable in
one second, and cannot hallucinate into a fixed key position.

## What would change this answer

The experiment tested a **general** model with **no personal data**. Both
are fixable, and either could flip the result:

1. **Personal history.** The model was asked what people say. It was never
   shown what *he* says. A table generated from his own sent messages is a
   different experiment, and the one the precompute architecture was
   actually for.
2. **Phrases, not words.** The measurement scores next-word prediction,
   where trigrams are strong. Whole-utterance suggestion — "can I go to
   the toilet please" as one tap — is where a model has room that a
   bigram table structurally cannot reach.
3. **A better prompt.** Two rounds moved it 1897 → 1879. That trend is
   real but the gap to 1847 is larger than prompt work has closed so far.

Reproduce any of it:

```bash
./Tools/predict-table/run.sh > table.json
./Tools/tapcost/run.sh --file Tools/tapcost/corpus-200.txt \
    --model-table table.json --model-weight 0.3
```

## Re-checked after the grammar work

Ali's response to the recommendation was to build the grammar and then
ask the model again. The grammar landed — plurals relabelled in place,
inverted auxiliaries offered in the bar, comparatives added as words —
and took the corpus from 1847 to **1797 taps**, 30 spelled words to 16.

The same table, against the better baseline:

| model weight | taps |
|---|---|
| none (baseline) | **1797** |
| 0.1 | 1799 |
| 0.3 | 1803 |
| 1.0 | 1811 |

Still worse at every weight, and **the gap widened**. That is the
expected direction and worth saying plainly: every rule added moves work
out of the space a next-word model could have helped with. Improving the
grammar does not make the model more useful, it makes it less.

## Best model available, and what to point it at

**Apple's on-device model, in the app, for phrases — not for words.**

It is the only option that satisfies invariant 5 (no network from the
keyboard, ever). It costs the extension no memory because inference runs
out-of-process in a system daemon. It reports `.available` on current
hardware. Any hosted model — GPT, Claude, Gemini — is disqualified before
cost is even discussed: what he types IS his speech, he cannot audit
where it goes, and consent would be given on his behalf forever.

Do not point it at next-word prediction. Three rounds against two
baselines agree, and the reason is structural rather than fixable by
prompting: the model reproduces the hand-tuned seeds where they exist and
guesses everywhere else.

Point it at the two things a bigram table structurally cannot do:

1. **Whole utterances.** "can I go to the toilet please" as one tap
   rather than six. `tapcost` already measures phrase cells — they are
   the cheapest thing on the board — so this is measurable the day it
   exists.
2. **His own sent messages.** The model was asked what people say. It has
   never been shown what he says, and that is the only input it has that
   the seeds do not.

## What is left, and why it is not a model problem

Nine of the sixteen remaining are past-tense forms: `was`, `did`,
`does`, `drew`, `forgot`, `made`, `played`, `started`, `took`. They share
one cause. English usually puts the time marker after the verb — "it
started yesterday" — so when he taps `start` the sentence is still just
"it" and the board has no way to know. Tapping `yesterday` first puts the
whole board in the past correctly, which is what the tense mechanism was
built for.

That is word order, not a missing feature, and no model fixes it: the
information genuinely is not there yet at the moment the key is pressed.

## The wider point

Both failures here were invisible to inspection and obvious to
measurement. The first table looked like a plausible word list and cost 50
taps. Without a number, it would have shipped — and at 30 seconds a tap,
50 taps is 25 minutes of somebody's life spent on a change made because it
sounded modern.
