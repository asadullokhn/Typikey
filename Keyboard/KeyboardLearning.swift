import UIKit
import NaturalLanguage

/// What the keyboard remembers, and what it offers next.
///
/// Capture is store-only and never logged. Prediction appears in the
/// suggestion bar and nowhere else — the grid never reorders itself to
/// make room for a guess (invariant 6).

extension KeyboardViewController {
    // MARK: Capture (Task G1 — letters-level typing, not grid-cell taps)

    /// Ends the current typed token — called on a terminator (space,
    /// return, grid punctuation, or a non-letter/non-apostrophe char).
    /// Counts it as a capture candidate when it has ≥3 letters (the
    /// apostrophe in a contraction like "don't" doesn't count toward
    /// that minimum, but stays in the stored/counted key) and isn't
    /// already known; always clears the accumulator either way.
    func terminateToken() {
        let token = typedToken
        typedToken = ""
        typedTokenTouchEvidence = nil
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
        // Bounded like the screen-learning stores. This one is written on
        // every space, and the words that would make it big are the ones
        // that never reached three sightings — typos and fragments.
        learn(WordCounts.trimmed(counts), forKey: "captureCounts")
    }

    /// Case-insensitive check against myWords and the built-in vocabulary
    /// — `token` is already lowercased by the time it reaches here.
    func isKnownWord(_ token: String) -> Bool {
        if myWords.contains(where: { $0.lowercased() == token }) { return true }
        return Self.knownVocabWords.contains(token)
    }

    // MARK: Prediction (on-device only — no Full Access, no network)

    /// The spell-check languages this system offers, resolved once.
    private static let checkerLanguages = UITextChecker.availableLanguages

    /// The language the user is ACTUALLY typing, detected from the field's
    /// own text — completions follow the text, not a settings toggle
    /// (Cotypist's "it just works in any language" feel). This outlived the
    /// EN/MS toggle on purpose: the board is English, but the field he is
    /// typing into might not be, and spell-check completions should follow
    /// what is actually on screen. Falls back to English on short or
    /// ambiguous context.
    func completionLanguage() -> String {
        let sample = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(200))
        guard sample.count >= 12 else { return "en_US" }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let detected = recognizer.dominantLanguage,
              (recognizer.languageHypotheses(withMaximum: 1)[detected] ?? 0) > 0.7,
              let match = Self.checkerLanguages.first(where: { $0.hasPrefix(detected.rawValue) })
        else { return "en_US" }
        return match
    }

    /// Screen learning input: the broadcast extension's word-frequency
    /// store, honored only while fresh. Without Full Access the key simply
    /// never exists in `.standard` and this stays empty.
    /// The single gate every piece of learning passes through. In private
    /// mode it does nothing, so a future feature cannot start remembering
    /// something by forgetting to check a flag — the check lives in one
    /// place rather than at seven call sites.
    func learn(_ value: Any, forKey key: String) {
        guard !isPrivate else { return }
        store.set(value, forKey: key)
    }

    func reloadScreenWords() {
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

    func reloadPersonalizationSnapshot() {
        guard hasFullAccess, !isPrivate,
              let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ScreenWords.suiteName) else {
            personalizationSnapshot = nil
            return
        }
        personalizationSnapshot = PersonalizationSnapshotStore(
            directoryURL: directory).load()
    }

    func promoteSnapshotWords() {
        guard !isPrivate, let snapshot = personalizationSnapshot else { return }
        var words = myWords
        var existing = Set(words.map { $0.lowercased() })
        let blocked = Set(snapshot.blockedWords.map { $0.lowercased() })
        for weighted in snapshot.words
        where weighted.weight >= 0.75 && words.count < myWords.count + 5 {
            let identity = weighted.text.lowercased()
            guard !blocked.contains(identity), existing.insert(identity).inserted else { continue }
            words.append(weighted.text)
        }
        guard words != myWords else { return }
        learn(words, forKey: "myWords")
        myWords = words
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
    func promoteFrequentWords() {
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

    func activeFieldProfile() -> FieldProfile {
        FieldProfile(traits: textDocumentProxy)
    }

    func predictionRequest() -> PredictionRequest {
        PredictionRequest(
            contextBefore: contextBefore(),
            partialWord: currentPartialWord(),
            sentenceStart: atSentenceStart(),
            fieldProfile: activeFieldProfile(),
            maximumCandidates: 3)
    }

    func refreshPredictionTrieIfNeeded() {
        let personalSignature = myWords.map { $0.lowercased() }.sorted().joined(separator: "|")
        let snapshotSignature = personalizationSnapshot?.words
            .map { "\($0.text.lowercased()):\($0.weight)" }.joined(separator: "|") ?? ""
        let screenSignature = screenWords.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }.joined(separator: "|")
        let usageSignature = usageCounts.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }.joined(separator: "|")
        let signature = personalSignature + "#" + snapshotSignature + "#"
            + screenSignature + "#" + usageSignature
        guard signature != predictionTrieSignature else { return }

        var frequencies: [String: (text: String, frequency: Int)] = [:]
        for word in vocabulary.flatMap(\.words).map(\.text) {
            let identity = word.lowercased()
            frequencies[identity] = (word, 1 + (usageCounts[word] ?? usageCounts[identity] ?? 0))
        }
        if !isPrivate {
            for word in myWords {
                frequencies[word.lowercased()] = (word, 100 + (usageCounts[word] ?? 0))
            }
            for (word, count) in screenWords {
                let identity = word.lowercased()
                let existing = frequencies[identity]
                frequencies[identity] = (existing?.text ?? word, max(existing?.frequency ?? 0, 20 + count))
            }
            for weighted in personalizationSnapshot?.words ?? [] {
                let identity = weighted.text.lowercased()
                let frequency = 40 + Int(min(1, weighted.weight) * 80)
                let existing = frequencies[identity]
                frequencies[identity] = (
                    existing?.text ?? weighted.text,
                    max(existing?.frequency ?? 0, frequency))
            }
        }
        predictionTrie = PrefixTrie(words: frequencies.values.map { ($0.text, $0.frequency) })
        predictionTrieSignature = signature
    }

    @MainActor
    func deterministicPredictions(for request: PredictionRequest) -> PredictionResult {
        refreshPredictionTrieIfNeeded()
        var candidates: [PredictionCandidate] = []
        let partial = request.partialWord.trimmingCharacters(in: .whitespacesAndNewlines)

        if !partial.isEmpty {
            let mine = Set(myWords.map { $0.lowercased() })
            let screen = Set(screenWords.keys.map { $0.lowercased() })
            for (index, word) in predictionTrie.completions(for: partial, limit: 12).enumerated() {
                let identity = word.lowercased()
                let source: PredictionSource
                if !isPrivate && mine.contains(identity) {
                    source = .personal
                } else if !isPrivate && screen.contains(identity) {
                    source = .screen
                } else {
                    source = .prefix
                }
                candidates.append(PredictionCandidate(
                    text: word,
                    score: Double(12 - index),
                    source: source))
            }
        } else if request.fieldProfile != .url && request.fieldProfile != .email {
            let predictionPlan = isPrivate
                ? BoardPlan(followsSentence: boardFollowsSentence, smartGrammar: smartGrammar)
                : plan
            let words = predictionPlan.predictions(
                after: request.sentenceStart ? "" : request.contextBefore)
            let previous = lastWord().lowercased()
            let learnedPrefix = "\(previous)|"
            let learnedWords = Set(learnedBigrams.keys.compactMap { key -> String? in
                guard key.hasPrefix(learnedPrefix) else { return nil }
                return String(key.dropFirst(learnedPrefix.count)).lowercased()
            })
            let screen = Set(screenWords.keys.map { $0.lowercased() })
            for (index, word) in words.enumerated() {
                let identity = word.lowercased()
                let source: PredictionSource
                if !isPrivate && learnedWords.contains(identity) {
                    source = .learnedNGram
                } else if !isPrivate && screen.contains(identity) {
                    source = .screen
                } else {
                    source = .seedNGram
                }
                candidates.append(PredictionCandidate(
                    text: word,
                    score: Double(max(1, words.count - index)),
                    source: source))
            }

            if request.sentenceStart {
                for (index, word) in predictionTrie.completions(for: "", limit: 6).enumerated() {
                    candidates.append(PredictionCandidate(
                        text: word,
                        score: Double(6 - index),
                        source: .prefix))
                }
            }
        }

        let ranked = PredictionRanker().rank(candidates, limit: request.maximumCandidates)
        return PredictionResult(
            candidates: ranked,
            generatedAt: .now,
            maximumCandidates: request.maximumCandidates)
    }

    func topVocabulary() -> [String] {
        // myWords go first and are never starved by usage ranking — the
        // user's own words matter for completion regardless of how often
        // built-in vocabulary has been used.
        let ranked = usageCounts.sorted { $0.value > $1.value }.map(\.key)
        let screenTop = screenWords.sorted { $0.value > $1.value }.prefix(10).map(\.key)
        let snapshotTop = personalizationSnapshot?.words.prefix(20).map(\.text) ?? []
        var seen = Set<String>()
        var result: [String] = []
        for word in myWords + snapshotTop + screenTop + ranked {
            guard !seen.contains(word) else { continue }
            seen.insert(word)
            result.append(word)
            if result.count == 40 { break }
        }
        return result
    }

    func requestPhraseCompletion() {
        guard isWordLevel else {
            completionWords = []
            return
        }
        guard !isPrivate,
              activeFieldProfile() != .url,
              activeFieldProfile() != .email else {
            completionWords = []
            return
        }
        // The live on-device model reads the sentence being written.
        // Personal phrases remain the offline fallback when the model is
        // unavailable or has no useful continuation.
        guard !completionEngine.isDegraded else {
            completionWords = personalizedCompletion(after: contextBefore())
                ?? []
            return
        }
        completionEngine.requestCompletion(
            context: contextBefore(),
            vocabulary: topVocabulary(),
            fieldProfile: activeFieldProfile()
        ) { [weak self] completion in
            guard let self else { return }
            // Only when the live model had nothing to say for this sentence.
            self.completionWords = completion?.words
                ?? self.personalizedCompletion(after: self.contextBefore())
                ?? []
            self.updateSuggestions()
        }
    }

    func personalizedCompletion(after context: String) -> [String]? {
        let typed = Grammar.words(in: Grammar.currentSentence(context).lowercased())
        for weighted in personalizationSnapshot?.phrases ?? [] {
            let phrase = Grammar.words(in: weighted.text.lowercased())
            guard phrase.count > typed.count,
                  zip(phrase, typed).allSatisfy({ $0 == $1 }) else { continue }
            return Array(phrase.dropFirst(typed.count).prefix(5))
        }
        return nil
    }

    func currentPartialWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        return context.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
    }

    func evaluateTypedTokenForCorrection(terminator: String) {
        guard !isPrivate, typedToken.count >= 2 else { return }
        let context = contextBefore()
        guard context.count >= typedToken.count else { return }
        let original = String(context.suffix(typedToken.count))
        let contextBeforeWord = String(context.dropLast(typedToken.count))

        var frequencies: [String: Int] = [:]
        for word in vocabulary.flatMap(\.words).map(\.text) {
            frequencies[word] = 1 + (usageCounts[word] ?? usageCounts[word.lowercased()] ?? 0)
        }
        for word in myWords {
            frequencies[word] = max(frequencies[word] ?? 0, 100 + (usageCounts[word] ?? 0))
        }
        let engine = CorrectionEngine(
            wordFrequencies: frequencies,
            personalWords: Set(myWords),
            bigramFrequencies: learnedBigrams,
            language: completionLanguage())
        let decision = engine.evaluate(
            committedWord: original,
            contextBeforeWord: contextBeforeWord,
            contextAfterWord: textDocumentProxy.documentContextAfterInput ?? "",
            touch: typedTokenTouchEvidence,
            fieldProfile: activeFieldProfile())
        switch decision {
        case .ignore:
            return
        case .suggest(let original, let replacement, _):
            guard let documentIdentifier = currentDocumentIdentifier else { return }
            pendingCorrection = SuggestedCorrection(
                original: original,
                replacement: replacement,
                documentIdentifier: documentIdentifier,
                expectedContextSuffix: original + terminator,
                terminator: terminator)
        case .replace(let original, let replacement, _):
            guard let documentIdentifier = currentDocumentIdentifier else { return }
            pendingAutomaticCorrection = SuggestedCorrection(
                original: original,
                replacement: replacement,
                documentIdentifier: documentIdentifier,
                expectedContextSuffix: original + terminator,
                terminator: terminator)
        }
    }

    func updateSuggestions() {
        let deterministic = deterministicPredictions(for: predictionRequest())
        let titles: [String]
        if let correction = appliedCorrection {
            titles = ["Undo \(correction.original)"]
        } else if let correction = pendingCorrection {
            var slots = [correction.replacement]
            for candidate in deterministic.candidates
            where !slots.contains(where: {
                $0.caseInsensitiveCompare(candidate.text) == .orderedSame
            }) {
                slots.append(candidate.text)
            }
            titles = Array(slots.prefix(3))
        } else if !rephrasings.isEmpty {
            // A whole sentence per chip rather than a word. He pressed the
            // question key, which is a deliberate act with one meaning,
            // and until he does something else this is the only thing the
            // bar has worth saying.
            titles = rephrasings
        } else if isWordLevel {
            if !completionWords.isEmpty {
                // Two chips, no symbols to decode: the short one is the next
                // word, the long one is the whole continuation. Since the
                // long chip starts with the short chip's word, the
                // relationship explains itself.
                var slots: [String] = [completionWords[0]]
                if completionWords.count >= 2 {
                    slots.append(completionWords.joined(separator: " "))
                }
                if let bigram = deterministic.candidates.first?.text,
                   !slots.contains(bigram),
                   bigram != completionWords[0] {
                    slots.append(bigram)
                }
                titles = Array(slots.prefix(3))
            } else {
                titles = deterministic.candidates.map(\.text)
            }
        } else {
            let word = currentPartialWord()
            if !word.isEmpty {
                // Screen-learned matches lead: a name or product word seen
                // on screen won't be in the system dictionary at all, and
                // that is exactly the word worth one tap instead of ten.
                var slots = deterministic.candidates.map(\.text)
                if word.count >= 2 {
                    let checker = UITextChecker()
                    let range = NSRange(location: 0, length: word.utf16.count)
                    for completion in checker.completions(
                        forPartialWordRange: range, in: word, language: completionLanguage()) ?? [] {
                        if !slots.contains(where: { $0.caseInsensitiveCompare(completion) == .orderedSame }) {
                            slots.append(completion)
                        }
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
        // A whole sentence needs room a single word does not, and the
        // chips have just changed how many of them there are.
        view.setNeedsLayout()
    }

    @objc func suggestionTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        haptics.commit()
        if let correction = appliedCorrection,
           title == "Undo \(correction.original)" {
            undoAppliedCorrection(correction)
            return
        }
        if let correction = pendingCorrection,
           title.caseInsensitiveCompare(correction.replacement) == .orderedSame {
            acceptPendingCorrection(correction)
            return
        }
        if rephrasings.contains(title) {
            replaceCurrentSentence(with: title)
            rephrasings = []
            updateSuggestions()
            refreshVerbForms()
            return
        }
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

    func acceptPendingCorrection(_ correction: SuggestedCorrection) {
        defer {
            pendingCorrection = nil
            updateSuggestions()
            refreshVerbForms()
        }
        guard CorrectionContextGuard.canApply(
            documentIdentifier: currentDocumentIdentifier,
            currentSuffix: contextBefore(),
            expectedDocumentIdentifier: correction.documentIdentifier,
            expectedSuffix: correction.expectedContextSuffix) else { return }
        for _ in 0..<correction.expectedContextSuffix.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(correction.replacement + correction.terminator)
    }

    func applyPendingAutomaticCorrection() {
        guard let correction = pendingAutomaticCorrection else { return }
        pendingAutomaticCorrection = nil
        guard CorrectionContextGuard.canApply(
            documentIdentifier: currentDocumentIdentifier,
            currentSuffix: contextBefore(),
            expectedDocumentIdentifier: correction.documentIdentifier,
            expectedSuffix: correction.expectedContextSuffix) else { return }

        isApplyingCorrection = true
        for _ in 0..<correction.expectedContextSuffix.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(correction.replacement + correction.terminator)
        isApplyingCorrection = false
        appliedCorrection = AppliedCorrection(
            original: correction.original,
            replacement: correction.replacement,
            documentIdentifier: correction.documentIdentifier,
            expectedContextSuffix: correction.replacement + correction.terminator)
        updateSuggestions()
    }

    func undoAppliedCorrection(_ correction: AppliedCorrection) {
        defer {
            appliedCorrection = nil
            updateSuggestions()
            refreshVerbForms()
        }
        guard CorrectionContextGuard.canUndo(
            correction,
            documentIdentifier: currentDocumentIdentifier,
            currentSuffix: contextBefore()) else { return }

        isApplyingCorrection = true
        for _ in 0..<correction.expectedContextSuffix.count {
            textDocumentProxy.deleteBackward()
        }
        let terminator = String(correction.expectedContextSuffix.dropFirst(correction.replacement.count))
        textDocumentProxy.insertText(correction.original + terminator)
        isApplyingCorrection = false
    }
}
