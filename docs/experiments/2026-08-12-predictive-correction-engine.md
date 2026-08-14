# Predictive and correction engine verification — 12 Aug 2026

Branch: `feat/native-predictive-auto-editing`

## Completed locally

- The complete `TypikeyTests` unit target passed on the iPad Pro 13-inch (M5), iOS 26.2 simulator.
- The app and all three extensions built in Release configuration.
- App-owned UI checks passed for the reference home structure, placeholder behavior, Setup navigation, conversation OCR, and screen-learning controls.
- Prefix lookup tests enforce P95 below 10 ms; touch filtering tests enforce P95 below 5 ms.
- A 25-case local correction holdout produced 100% suggestion precision, 100% recall, zero false suggestions, zero automatic replacements, and 0.035 ms reverse-analysis P95.
- The 200-sentence corpus remained at 1,814 taps, 1.97 taps per word, and 16 spelled words. Generic deterministic Top-3 accuracy was 122/885, or 13.8%.

## Gates not yet satisfied

- The 72% Top-3 target is not met by the generic unpersonalized corpus. A representative personalized holdout and physical-device model-enriched run are still required.
- Automatic replacement remains disabled. The 25-case correction set is too small to qualify as the frozen untouched user holdout required for the 95% release gate.
- The simulator has no active Typikey keyboard, so extension-owned edge-column and height UI tests stop at their explicit precondition. App-owned reference layout tests pass.
- Foundation Models cold, prewarmed-first, and warm latency, physical footprint, thermals, jetsam behavior, and sustained typing endurance require an Apple Intelligence-capable physical iPad.
- The latest existing simulator footprint reading is 58.3 MB; it is indicative only and exceeds the 30 MB project target. No new physical-device reading was performed in this run.

No raw prompt, typed context, touch trace, calendar detail, event attendee, location coordinate, or message content is written by the new engine. Personalization publication contains bounded weighted words, short phrases, blocked words, and a timestamp only.
