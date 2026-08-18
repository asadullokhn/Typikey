import UIKit
import NaturalLanguage

/// Touch to text: explore-then-commit, and what a commit does.
///
/// Touching down costs nothing, sliding moves the highlight, and only
/// lifting commits (invariant 2). Every point maps to the nearest key, so
/// precision is never required (invariant 4). This is the file where a
/// mistake costs him a word he did not mean to say.

extension KeyboardViewController {
    // MARK: Explore-then-commit (called by TrackingView)

    func handleTouch(_ sample: TouchSample) {
        if sample.phase == .began {
            lastTouchEvidence = nil
        }
        let evidence = touchIntentFilter.consume(
            sample, keyFrames: keys.map { $0.view.frame })
        switch sample.phase {
        case .began, .moved:
            touchMoved(to: sample.point)
        case .ended:
            lastTouchEvidence = evidence
            touchLifted(at: sample.point)
        case .cancelled:
            lastTouchEvidence = nil
            touchCancelled()
        }
    }

    func resetTouchIntent() {
        touchIntentFilter.reset()
        lastTouchEvidence = nil
    }

    func touchMoved(to point: CGPoint) {
        let index = keyIndex(at: point)
        guard index != highlightedIndex else { return }
        // Crossing onto a new key is the moment the user needs confirming:
        // sliding is free exploration, so this tick is how the board is read
        // by feel rather than by eye.
        if index != nil { haptics.slidToNewKey() }
        let old = highlightedIndex
        highlightedIndex = index
        if let old { style(keys[old].view, action: keys[old].action, label: keys[old].label, highlighted: false) }
        if let index { style(keys[index].view, action: keys[index].action, label: keys[index].label, highlighted: true) }
    }

    func touchLifted(at point: CGPoint) {
        let index = keyIndex(at: point)
        highlightedIndex = nil
        restyleAll()
        guard let index else { return }
        commit(keys[index].action)
    }

    func touchCancelled() {
        highlightedIndex = nil
        restyleAll()
    }

    /// No dead zones: any point below the suggestion bar maps to the
    /// nearest key by center distance.
    func keyIndex(at point: CGPoint) -> Int? {
        guard point.y > layoutYOffset + topBarHeight else { return nil } // suggestion buttons handle themselves
        var best: (index: Int, distance: CGFloat)?
        for (i, key) in keys.enumerated() {
            if key.view.frame.contains(point) { return i }
            let c = CGPoint(x: key.view.frame.midX, y: key.view.frame.midY)
            let d = hypot(c.x - point.x, c.y - point.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }

    // MARK: Committing

    func commit(_ action: KeyAction) {
        // Double-tap guard; delete, word-delete, clear-all, and the
        // cursor arrows are exempt — repeats are intentional for those.
        if !isDebounceExempt(action),
           let last = lastCommit, last.action == action,
           Date().timeIntervalSince(last.at) < debounceInterval {
            return
        }
        pendingCorrection = nil
        pendingAutomaticCorrection = nil
        appliedCorrection = nil
        haptics.commit()
        lastCommit = (action, Date())

        switch action {
        case .word(let w):
            rephrasings = []
            insertWord(w)
        case .punct(let p):
            evaluateTypedTokenForCorrection(terminator: p + " ")
            terminateToken()
            // Read the sentence before the mark goes in: the proxy lags
            // its own insertion, and this has to see the words rather than
            // the punctuation.
            let finished = contextBefore()
            insertPunctuation(p)
            rephrasings = p == "?" ? Rephrase.questions(from: finished) : []
        case .char(let c):
            // An apostrophe is token-internal (so "don't" accumulates as
            // one token) even though it isn't a letter — terminateToken's
            // ≥3 requirement below counts letters only, so it doesn't
            // inflate the count, but the stored/counted key keeps it.
            if let ch = c.first, c.count == 1, ch.isLetter || ch == "'" || ch == "\u{2019}" {
                typedToken += c.lowercased()
            } else {
                terminateToken()
            }
            textDocumentProxy.insertText(shifted ? c.uppercased() : c)
            typedTokenTouchEvidence = lastTouchEvidence
            if shifted { shifted = false; restyleAll() }
        case .shift:
            shifted.toggle()
            restyleAll()
        case .delete:
            // Deleting mid-word makes the accumulated token unreliable —
            // reset rather than count a partial/garbled word.
            typedToken = ""
            typedTokenTouchEvidence = nil
            rephrasings = []
            textDocumentProxy.deleteBackward()
        case .deleteWord:
            typedToken = ""
            rephrasings = []
            deleteLastWord()
        case .home:
            typedToken = ""
            completionWords = []
            level = .home; buildKeys()
        case .toCategories:
            typedToken = ""
            completionWords = []
            level = .categories; buildKeys()
        case .toWords(let i):
            typedToken = ""
            completionWords = []
            level = .words(i); buildKeys()
        case .toPage(let id):
            typedToken = ""
            completionWords = []
            level = .page(id); buildKeys()
        case .toLetters:
            typedToken = ""
            completionWords = []
            level = .letters; buildKeys()
        case .toNumbers:
            typedToken = ""
            completionWords = []
            level = .numbers; buildKeys()
        case .clearAll:
            typedToken = ""
            completionWords = []
            handleClearAll()
        case .cursorLeft:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        case .cursorRight:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        case .space:
            evaluateTypedTokenForCorrection(terminator: " ")
            terminateToken()
            typedTokenTouchEvidence = nil
            textDocumentProxy.insertText(" ")
        case .ret:
            evaluateTypedTokenForCorrection(terminator: "\n")
            terminateToken()
            typedTokenTouchEvidence = nil
            textDocumentProxy.insertText("\n")
        case .dismiss:
            let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
            persistPendingRestore(signature: signature, level: level)
            dismissKeyboard()
        }
        updateSuggestions()
        requestPhraseCompletion()
        if pendingAutomaticCorrection != nil {
            DispatchQueue.main.async { [weak self] in
                self?.applyPendingAutomaticCorrection()
            }
        }
        // The document proxy can lag its own insertion by a run loop, so a
        // form change caused by THIS commit is not always visible to
        // textDidChange when it fires. Re-check once the text has settled:
        // that is what was leaving the board in the past tense after a full
        // stop had already ended the sentence. refreshVerbForms rebuilds
        // only when the board would actually read differently, so this
        // costs nothing on the commits that change nothing.
        DispatchQueue.main.async { [weak self] in
            self?.refreshVerbForms()
            self?.syncReturnKey()
        }
    }

    /// Repeats are intentional for deletes and cursor movement; clear-all
    /// has its own two-tap arm and must not have its second tap swallowed.
    func isDebounceExempt(_ action: KeyAction) -> Bool {
        switch action {
        case .delete, .deleteWord, .clearAll, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    func handleClearAll() {
        clearAllText()
    }

    /// Clears everything the field exposes. Extensions only see a context
    /// window; in his real use (messages, search) that is the whole text.
    func clearAllText() {
        if let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
        }
        var passes = 0
        while let before = textDocumentProxy.documentContextBeforeInput,
              !before.isEmpty, passes < 200 {
            for _ in 0..<before.count { textDocumentProxy.deleteBackward() }
            passes += 1
        }
    }

    func contextBefore() -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    /// True at the start of the document or after sentence-ending punctuation.
    func atSentenceStart() -> Bool {
        let trimmed = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return ".!?".contains(last)
    }

    /// Last completed word before the cursor, for prediction and learning.
    func lastWord() -> String {
        let context = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        let token = context.split(whereSeparator: { $0 == " " || $0 == "\n" }).last.map(String.init) ?? ""
        return token.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,"))
    }

    /// One tap = one word. Handles spacing, sentence-start capitalization,
    /// and records usage so Recents and prediction improve over time.
    func insertWord(_ word: String) {
        let previous = lastWord()

        var text = word
        let joined = WordJoin.leads(word) || WordJoin.continues(contextBefore())
        if !joined, !WordJoin.isJoiner(word),
           atSentenceStart(), let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }
        // ".com" pulls back onto the word before it, the way punctuation does.
        if WordJoin.leads(word), contextBefore().last == " " {
            textDocumentProxy.deleteBackward()
        } else if !joined, let last = contextBefore().last, last != " ", last != "\n" {
            textDocumentProxy.insertText(" ")
        }
        textDocumentProxy.insertText(WordJoin.trails(word) ? text : text + " ")

        // Count the base word, not the inflected label: "go", "goes" and
        // "going" are one key and one habit, and Recents would otherwise
        // fill up with three entries for the same cell.
        let counted = inflectionBase[word] ?? word
        usageCounts[counted, default: 0] += 1
        learn(usageCounts, forKey: "usage")
        if !previous.isEmpty {
            learnedBigrams["\(previous.lowercased())|\(counted)", default: 0] += 1
            learn(learnedBigrams, forKey: "bigrams")
        }
        refreshVerbForms()
    }

    /// Punctuation attaches to the word before it: "hello ." → "hello. "
    func insertPunctuation(_ p: String) {
        if contextBefore().last == " " {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(p + " ")
    }

    /// Swaps the sentence just finished for a rephrasing of it.
    ///
    /// Deletes back to wherever this sentence began — not a fixed number
    /// of characters, because the question key writes a mark and a space
    /// and the sentence before it may have ended in either. Anything in
    /// front of it is a different sentence and is not touched, and the
    /// space separating them is put back, so accepting a rephrasing in the
    /// middle of a conversation does not run two sentences together.
    func replaceCurrentSentence(with replacement: String) {
        let context = contextBefore()
        guard !context.isEmpty else { return }

        var end = context.endIndex
        while end > context.startIndex,
              " \n".contains(context[context.index(before: end)]) {
            end = context.index(before: end)
        }
        if end > context.startIndex, ".!?".contains(context[context.index(before: end)]) {
            end = context.index(before: end)
        }
        let start = context[..<end]
            .lastIndex(where: { ".!?\n".contains($0) })
            .map { context.index(after: $0) } ?? context.startIndex

        let sentence = context[start...]
        let separator = sentence.prefix { $0 == " " || $0 == "\n" }
        for _ in 0..<sentence.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(separator + replacement + " ")
    }

    func deleteLastWord() {
        var context = contextBefore()
        guard !context.isEmpty else { return }
        while let last = context.last, last == " " {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
        while let last = context.last, last != " ", last != "\n" {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
    }
}
