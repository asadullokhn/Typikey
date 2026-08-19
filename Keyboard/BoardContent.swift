import UIKit
import NaturalLanguage

/// What the board shows, level by level.
///
/// The frame — the pinned column, the grid controls, the row and column
/// counts — is identical on every level by design (invariant 9), and the
/// only thing that changes between them is which cells fill the middle.
/// Keeping that decision in one file is what makes it checkable.

extension KeyboardViewController {
    // MARK: Categories

    /// Tab 0 is Recents — computed from usage.
    ///
    /// His own words count here too. They used to fall out: Recents looked
    /// every used word up in `vocabIndex`, which only knows the built-in
    /// vocabulary, so a name he added and then used every day could never
    /// reach the one board that exists to shorten the reach to what he
    /// actually says.
    func allCategories() -> [(name: String, words: [VocabWord])] {
        let recents = usageCounts
            .sorted { $0.value > $1.value }
            .compactMap { vocabIndex[$0.key] ?? myWord(named: $0.key) }
        var seen = Set<String>()
        var unique: [VocabWord] = []
        for word in recents where !seen.contains(word.text) {
            seen.insert(word.text)
            unique.append(word)
            if unique.count == wordSlots { break }
        }
        let recentsName = "Recents"
        // Mine appends after the built-in categories — never reorders them
        // (invariant 1). Plain-text cells built on the fly; myWords are
        // never added to vocabIndex (that stays the built-in lookup only).
        // Mine is the one board that grows on its own — promotion adds
        // words whenever they earn it — so it is the one that can outgrow
        // the grid. Capped deliberately here rather than left to the
        // packer, which drops the overflow without saying so.
        //
        // Capped in insertion order, not by how often each word is used.
        // Usage order would reshuffle the board under his fingers every
        // time a count changed, which is the one thing invariant 1 exists
        // to prevent. The cost is that a word past the cap does not appear
        // on the board; it is still in My Words, still offered by
        // prediction and completion, and the app now says how many are
        // over so he can prune.
        let mineWords = myWords.prefix(wordSlots).map { VocabWord($0, .social) }
        // Auto-filing (Gilbert: the board should quietly configure itself,
        // but visibly, so nobody hunts for a word): a user's word that is
        // recognizably a person, place, or action ALSO appears at the end
        // of that category's page (invariant 1: new words go at the end),
        // in Mine's pink so it always reads as "his word". Everything
        // still lives in Mine regardless; ambiguous words stay Mine-only.
        var builtIn = vocabulary.map { (name: $0.name, en: $0.name, words: $0.words) }
        for word in myWords {
            guard let target = autoCategory(for: word),
                  let i = builtIn.firstIndex(where: { $0.en == target }),
                  !builtIn[i].words.contains(where: { $0.text.caseInsensitiveCompare(word) == .orderedSame })
            else { continue }
            builtIn[i].words.append(VocabWord(word, .social))
        }
        // The order Fadillah arranged in the app, if she has. Nothing
        // stored means the shipped order, which is also what a failed read
        // and a revoked Full Access give — the board must never be the
        // reason he cannot find a word.
        //
        // Named lookup rather than index arithmetic: a stored arrangement
        // can name a board that no longer ships, and a build that shipped
        // a new one must not shuffle everything after it.
        var byName = [recentsName: unique, "Mine": mineWords]
        for board in builtIn { byName[board.name] = board.words }
        return BoardLayout.load(from: store).compactMap { tile in
            byName[tile.id].map { (tile.name, $0) }
        }
    }

    /// A word of the user's own, as a cell. Matched case-insensitively
    /// because usage is counted on the text that was inserted and My Words
    /// stores names capitalised.
    func myWord(named word: String) -> VocabWord? {
        myWords.first { $0.caseInsensitiveCompare(word) == .orderedSame }
            .map { VocabWord($0, .social) }
    }

    /// On-device semantic filing for a user's word: personal names go to
    /// People, place names to Places, verbs to Actions. Single words only —
    /// phrases stay Mine-only.
    ///
    /// Remembered in the store, not just in memory. `WordFiling` runs a
    /// tagger over three carrier sentences per word, and this cache used to
    /// die with the keyboard instance — so every fresh keyboard paid that
    /// cost again, for every word he has ever added, inside a process with
    /// a 60-80MB ceiling and a board that rebuilds whenever the verb form
    /// changes. Words only accumulate, so that bill only grows. A word's
    /// reading never changes; it is worth writing down.
    ///
    /// Empty string means "filed nowhere" — a plist cannot hold nil, and
    /// the distinction between "no category" and "not looked at yet" is the
    /// whole point of the cache.
    func autoCategory(for word: String) -> String? {
        if let cached = autoFileCache[word] { return cached.isEmpty ? nil : cached }
        let result = WordFiling.category(for: word)
        autoFileCache[word] = result ?? ""
        learn(autoFileCache, forKey: "wordFiling")
        return result
    }

    // MARK: Frame (fixed controls on both edges)

    var leftEdgeColumn: [ContentCell] { BoardFrame.leftColumn }

    var rightEdgeTop: ContentCell { BoardFrame.rightTop(level: level) }

    /// allCategories() index of the Chat board (offset 1 for Recents).
    var chatWordsIndex: Int {
        (vocabulary.firstIndex { $0.name == "Chat" } ?? 0) + 1
    }

    /// allCategories() index of the Web board (offset 1 for Recents).
    var webWordsIndex: Int {
        (vocabulary.firstIndex { $0.name == "Web" } ?? 0) + 1
    }

    /// allCategories() index of the Sites board (offset 1 for Recents).
    var sitesWordsIndex: Int {
        (vocabulary.firstIndex { $0.name == "Sites" } ?? 0) + 1
    }

    /// Spec: applied once when the keyboard attaches to a field; never
    /// switches mid-typing. Manual navigation always wins afterwards.
    ///
    /// Keyboard extensions have no field-identity API, so `viewWillAppear`
    /// only recomputes this mapping when the field's keyboardType/
    /// returnKeyType signature differs from the last one THIS INSTANCE
    /// saw (`lastIntentSignature`, plain in-memory — correct whenever the
    /// instance itself survives the reshow, e.g. ordinary backgrounding/
    /// foregrounding of a still-visible keyboard).
    ///
    /// Tapping the in-keyboard ⌄ key (`commit(.dismiss)`) can additionally
    /// tear down and recreate the whole controller instance before the
    /// field is retapped — instance survival across that specific
    /// dismiss+retap is NOT an API guarantee either way, so
    /// `commit(.dismiss)` also writes the current signature, level, and
    /// a timestamp to UserDefaults via `persistPendingRestore`.
    /// `viewWillAppear` calls `consumePendingRestore` UNCONDITIONALLY,
    /// once, at the very top of every appearance — on every instance,
    /// regardless of whether that instance's own `lastIntentSignature`
    /// already matches — and the note is always read and cleared
    /// together in that one call. It is applied only if the signature
    /// still matches and it is no older than `pendingRestoreTTL` (120s).
    /// That unconditional consume is what keeps the note from surviving
    /// past the single reshow it was written for: a note nobody follows
    /// up on (dismissed, never retapped) cannot linger to ambush some
    /// unrelated later field that happens to share the same signature —
    /// it is gone (read and cleared) the very next time ANY field
    /// attaches, matching or not.
    ///
    /// Known accepted miss: retapping a *different* field that happens
    /// to share the exact same signature within the TTL window of a
    /// dismiss inherits the dismissed field's level instead of getting a
    /// fresh mapping — there is no way to tell that case apart from a
    /// re-show of the same field.
    func applyIntentLevel() {
        switch textDocumentProxy.keyboardType {
        case .numberPad?, .decimalPad?, .phonePad?:
            level = .numbers; return
        case .emailAddress?:
            // An address is spelled, not chosen from a board.
            level = .letters; return
        case .URL?:
            // An address bar is almost nothing but proper nouns, which are
            // the most expensive thing here to spell — so it gets the board
            // of site names rather than the letters. Search words would be
            // the wrong ones: nobody types `highlights` into an address bar.
            level = .words(sitesWordsIndex); return
        case .webSearch?:
            // A search box wants whole words — "YouTube", "how to" — far
            // more than it wants letters, and letters are one tap away.
            level = .words(webWordsIndex); return
        case .asciiCapable?:
            level = .letters; return
        default:
            break
        }
        switch textDocumentProxy.returnKeyType {
        case .google?, .yahoo?: level = .words(webWordsIndex)
        case .search?: level = .words(webWordsIndex)
        case .send?: level = .words(chatWordsIndex)
        default: level = .home
        }
    }

    /// A restore only makes sense moments after a dismiss — past this
    /// age a note is more likely to ambush some unrelated later field
    /// than to reflect a genuine reshow, so consumePendingRestore treats
    /// it as absent (while still clearing it).
    /// Called right before `dismissKeyboard()` so the level survives even
    /// if dismissing tears down this controller instance.
    func persistPendingRestore(signature: String, level: BoardLevel) {
        let defaults = UserDefaults.standard
        defaults.set(signature, forKey: "pendingRestoreSignature")
        defaults.set(Date().timeIntervalSince1970, forKey: "pendingRestoreTimestamp")
        switch level {
        case .home: defaults.set("home", forKey: "pendingRestoreLevel")
        case .categories: defaults.set("categories", forKey: "pendingRestoreLevel")
        case .letters: defaults.set("letters", forKey: "pendingRestoreLevel")
        case .numbers: defaults.set("numbers", forKey: "pendingRestoreLevel")
        case .page(let id):
            defaults.set("page", forKey: "pendingRestoreLevel")
            defaults.set(id, forKey: "pendingRestorePageID")
        case .words(let index):
            defaults.set("words", forKey: "pendingRestoreLevel")
            defaults.set(index, forKey: "pendingRestoreWordsIndex")
        }
    }

    /// Reads AND clears any pending restore from a prior dismiss —
    /// called unconditionally, once, at the top of every
    /// `viewWillAppear`, regardless of whether the caller's own
    /// `lastIntentSignature` already matches. That unconditional call is
    /// what guarantees a note never outlives the single appearance it
    /// was written for: it is gone after this one read, whether or not
    /// it matched. Returns the saved level only when the signature still
    /// matches and the note is fresh (see `pendingRestoreTTL`); returns
    /// nil (having still cleared it) otherwise.
    func consumePendingRestore(matching signature: String) -> BoardLevel? {
        let defaults = UserDefaults.standard
        let pendingSignature = defaults.string(forKey: "pendingRestoreSignature")
        let pendingLevel = defaults.string(forKey: "pendingRestoreLevel")
        let pendingWordsIndex = defaults.integer(forKey: "pendingRestoreWordsIndex")
        let pendingPageID = defaults.string(forKey: "pendingRestorePageID")
        let pendingTimestamp = defaults.object(forKey: "pendingRestoreTimestamp") as? TimeInterval
        defaults.removeObject(forKey: "pendingRestoreSignature")
        defaults.removeObject(forKey: "pendingRestoreLevel")
        defaults.removeObject(forKey: "pendingRestoreWordsIndex")
        defaults.removeObject(forKey: "pendingRestorePageID")
        defaults.removeObject(forKey: "pendingRestoreTimestamp")
        guard pendingSignature == signature,
              let pendingTimestamp, Date().timeIntervalSince1970 - pendingTimestamp <= pendingRestoreTTL
        else { return nil }
        switch pendingLevel {
        case "home": return .home
        case "categories": return .categories
        case "letters": return .letters
        case "numbers": return .numbers
        case "words": return .words(pendingWordsIndex)
        // A page that was deleted while the keyboard was away restores to
        // home rather than to nothing.
        case "page":
            guard let pendingPageID, customPage(pendingPageID) != nil else { return .home }
            return .page(pendingPageID)
        default: return nil
        }
    }

    /// Go key follows the field, like the system keyboard's return key.
    func goLabel() -> String {
        switch textDocumentProxy.returnKeyType {
        case .search?, .google?, .yahoo?: return "Search"
        case .send?: return "Send"
        case .go?: return "Go"
        case .done?: return "Done"
        default: return "Enter"
        }
    }

    /// The shared abc/123 layout, in this target's own cell type.
    func contentCell(_ cell: TypingLayout.Cell?) -> ContentCell? {
        guard let cell else { return nil }
        let action: KeyAction
        switch cell.key {
        case .char(let c):   action = .char(c)
        case .shift:         action = .shift
        case .space:         action = .space
        case .delete:        action = .delete
        case .cursorLeft:    action = .cursorLeft
        case .cursorRight:   action = .cursorRight
        case .toLetters:     action = .toLetters
        case .toNumbers:     action = .toNumbers
        }
        return ContentCell(action, cell.label, colSpan: cell.colSpan)
    }

    /// The boards Fadillah built in the app, or nil if she has not.
    ///
    /// nil is the important case and the common one: no stored pages means
    /// the keyboard behaves exactly as it did before this feature existed.
    /// A failed read, a revoked Full Access and a fresh install all land
    /// here, and all three have to leave him with a working board — the
    /// app is allowed to improve the keyboard and is never allowed to be
    /// the reason it stops working.
    var customPages: [KeyboardPage]? {
        guard store.data(forKey: BoardLayout.pagesKey) != nil else { return nil }
        let pages = BoardLayout.loadPages(from: store)
        return pages.isEmpty ? nil : pages
    }

    func customPage(_ id: String) -> KeyboardPage? {
        customPages?.first { $0.id == id }
    }

    /// A page laid out where the editor put it.
    ///
    /// Positional, not packed: cell 12 is row 1, column 2, and stays there
    /// whatever happens to cell 11. The packer that builds the shipped
    /// boards closes up behind an empty cell, which is right when a board
    /// is generated and wrong when a person arranged it — she put that key
    /// there on purpose, and he learned where it is.
    func pageRows(_ page: KeyboardPage, reshaped: Bool = false) -> [[ContentCell?]] {
        // Arranging a board used to switch the spare-cell replacement off
        // wholesale, on the reasoning that words must not move under
        // somebody who placed them. That is right for a board she laid out
        // key by key and wrong for home, where editing one cell silently
        // cost the whole feature. Reshaping runs over the words she left in
        // place; the keys she gave a destination never move.
        var page = page
        if reshaped {
            let order = plan.reshaped(
                page.cells.compactMap { $0?.destination == nil ? $0?.label : nil }
                    .compactMap { vocabIndex[$0] },
                after: contextBefore())
            var next = order.makeIterator()
            for i in page.cells.indices where page.cells[i]?.destination == nil {
                guard page.cells[i] != nil, let word = next.next() else { continue }
                page.cells[i]?.label = word.text
            }
        }
        return laidOut(page)
    }

    private func laidOut(_ page: KeyboardPage) -> [[ContentCell?]] {
        let cols = contentColumns
        var rows: [[ContentCell?]] = Array(
            repeating: Array(repeating: nil, count: cols), count: wordBoardRows)
        for (index, button) in page.cells.enumerated() {
            guard let button else { continue }
            let row = index / KeyboardPage.columns
            let column = index % KeyboardPage.columns
            guard row < wordBoardRows, column < cols else { continue }
            if let destination = button.destination {
                rows[row][column] = ContentCell(.toPage(destination), button.label)
            } else if let word = vocabIndex[button.label] {
                // Relabelled where it stands, never moved: she placed this
                // key, so reshaping stays off, but "go" still becomes "going".
                rows[row][column] = wordCell(word)
            } else {
                rows[row][column] = ContentCell(.word(button.label), button.label)
            }
        }
        // The design's controls go on last so a key can never bury one.
        for control in gridControls(rows: wordBoardRows) {
            guard control.row < rows.count, control.col < cols else { continue }
            rows[control.row][control.col] = control.cell
        }
        return rows
    }

    /// How the board decides what to show, and the only place that
    /// decision lives. Rebuilt per use rather than cached: it is four
    /// dictionaries by reference, and a stale copy would mean the board
    /// answering from learning the keyboard has already moved past.
    var plan: BoardPlan {
        BoardPlan(
            learning: .init(usage: usageCounts, bigrams: learnedBigrams,
                            screen: screenWords, mine: myWords),
            followsSentence: boardFollowsSentence,
            smartGrammar: smartGrammar)
    }


    func wordCell(_ word: VocabWord) -> ContentCell {
        let (text, base) = plan.label(for: word, after: contextBefore())
        if text != base { inflectionBase[text] = base }
        return ContentCell(word.wordClass == .punct ? .punct(text) : .word(text), text)
    }

    func contentRows(for level: BoardLevel) -> [[ContentCell?]] {
        switch level {
        case .page(let id):
            guard let page = customPage(id) else { return contentRows(for: .home) }
            return pageRows(page)
        case .home:
            // A home board she arranged replaces the shipped one, keys and
            // order both. Grammar and prediction survive that — they read
            // the text, not the board — but the spare-cell reshaping does
            // not, because it works by moving words and she put those keys
            // where they are.
            if let home = customPage("home"), BoardLayout.isArranged(home) {
                return pageRows(home, reshaped: true)
            }
            let cells = plan.reshaped(BoardPlan.homeWords, after: contextBefore())
                .prefix(wordSlots)
                .map(wordCell)
            return board(cells)
        case .categories:
            // Wide, short tiles rather than the old 2x2 blocks: now that
            // four grid slots belong to Enter, ⌄ and →, a 2x2 tiling no
            // longer fits eleven categories into four rows — and a category
            // that needs a taller keyboard to reach is one he won't find.
            let all = allCategories()
            // Wide tiles read better, and a board that silently drops its
            // last category reads worst of all — that last one is Mine, the
            // words he added himself. Two columns per tile while they fit,
            // one when they stop, so a new category narrows the board rather
            // than deleting one off the end of it.
            let span = contentColumns >= 8 && all.count <= categoryTileCapacity(span: 2) ? 2 : 1
            return board(all.enumerated().map {
                ContentCell(.toWords($0.offset), $0.element.name, colSpan: span)
            })
        case .words(let index):
            let categories = allCategories()
            let words = index < categories.count ? categories[index].words : []
            guard !words.isEmpty else {
                return board([emptyHint(forCategoryAt: index, of: categories.count)])
            }
            // Vocabulary can grow beyond the fixed board. Keep the ranked
            // words that fit; the rest remain available through ABC.
            let cells = plan.reshaped(words, after: contextBefore())
                .prefix(wordSlots)
                .map(wordCell)
            return board(cells)
        case .letters:
            return TypingLayout.letters.map { $0.map(contentCell) }
        case .numbers:
            return TypingLayout.numbers.map { $0.map(contentCell) }
        }
    }

    /// Mine's empty state isn't Recents' "used often" story. Mine is
    /// always the last category `allCategories()` appends, so that's the
    /// robust way to detect it — never a name string match. Recents' hint
    /// jumps to Core (toWords(1)) since its text points there; Mine's hint
    /// has nowhere in particular to go, so it backs out to the picker.
    func emptyHint(forCategoryAt index: Int, of count: Int) -> ContentCell {
        let isMine = index == count - 1
        let hint = isMine
            ? "Add words in the Typikey app"
            : "Words you use often will appear here"
        return ContentCell(isMine ? .toCategories : .toWords(1), hint, colSpan: contentColumns)
    }

    /// The two bottom corners are the cursor keys, as the app's board editor
    /// has always drawn them. Cursor left used to be omitted here, which is
    /// why the two boards disagreed about how many words fit.
    ///
    /// `board` lays these down before any word, so a word can never be
    /// silently overwritten by one — which is how cells used to vanish.
    func gridControls(rows rowCount: Int) -> [(cell: ContentCell, row: Int, col: Int)] {
        [(ContentCell(.pageBack, BoardFrame.stepLabel(for: .pageBack)), rowCount - 1, 0),
         (ContentCell(.pageForward, BoardFrame.stepLabel(for: .pageForward)),
          rowCount - 1, contentColumns - 1)]
    }

    /// How many word cells a board actually has, once the design's
    /// controls have taken theirs. Derived from `gridControls` rather than
    /// written down a second time, so moving a control can never leave a
    /// stale number behind.
    /// The board one step along, wrapping at both ends.
    ///
    /// Home sits at the front of the list and the categories follow it in
    /// the order the grid shows them, so stepping is the same journey the
    /// Categories screen offers — just without having to go through it.
    /// Levels that are not part of that walk step back onto home.
    func steppedLevel(by delta: Int) -> BoardLevel {
        let count = allCategories().count
        guard count > 0 else { return .home }
        let stops = count + 1                      // home, then every category
        let current: Int
        switch level {
        case .home: current = 0
        case .words(let i) where i < count: current = i + 1
        default: return .home
        }
        let next = ((current + delta) % stops + stops) % stops
        return next == 0 ? .home : .words(next - 1)
    }

    /// How many tiles of a given width the word board actually holds, once
    /// the two reserved corners have taken their cells out of the run.
    func categoryTileCapacity(span: Int) -> Int {
        guard span > 0 else { return 0 }
        var tiles = 0
        for row in 0..<wordBoardRows {
            var column = 0
            while column + span <= contentColumns {
                let cells = (0..<span).map { row * contentColumns + column + $0 }
                if cells.allSatisfy({ !BoardFrame.cursorCells.contains($0) }) {
                    tiles += 1
                    column += span
                } else {
                    column += 1
                }
            }
        }
        return tiles
    }

    var wordSlots: Int {
        let reserved = gridControls(rows: wordBoardRows)
            .reduce(0) { $0 + $1.cell.colSpan }
        return max(0, wordBoardRows * contentColumns - reserved)
    }

    /// Packs cells row-major into a word board, around the fixed controls.
    /// A cell that doesn't fit the free run where it lands slides right and
    /// then down, so a wide cell never straddles a control.
    func board(_ cells: [ContentCell]) -> [[ContentCell?]] {
        let cols = contentColumns
        let rowCount = wordBoardRows
        var rows: [[ContentCell?]] = Array(
            repeating: Array(repeating: nil, count: cols), count: rowCount)
        var taken = Set<Int>()

        func place(_ cell: ContentCell, row: Int, col: Int) {
            rows[row][col] = cell
            for r in row..<min(row + cell.rowSpan, rowCount) {
                for c in col..<min(col + cell.colSpan, cols) { taken.insert(r * cols + c) }
            }
        }
        for control in gridControls(rows: rowCount) {
            place(control.cell, row: control.row, col: control.col)
        }

        var next = 0
        for row in 0..<rowCount {
            var col = 0
            while col < cols, next < cells.count {
                let span = min(cells[next].colSpan, cols)
                let free = col + span <= cols
                    && !(col..<(col + span)).contains { taken.contains(row * cols + $0) }
                if free {
                    place(cells[next], row: row, col: col)
                    next += 1
                    col += span
                } else {
                    col += 1
                }
            }
        }
        // A board with more cells than slots loses the overflow without a
        // trace: no gap, no crash, the word simply is not there. Core grew
        // to 54 words on a 36-cell board that way, and eleven of them
        // existed on no board in the app at all.
        //
        // This used to exempt the narrow layouts, on the grounds that they
        // could not hold everything — which was true, and was exactly how
        // an iPad in Split View came to drop twenty of home's words without
        // anyone noticing. Every layout holds 36 word cells now, so the
        // check covers all of them. Anything that genuinely has to be cut
        // is cut deliberately at the call site, as Mine and Recents are.
        assert(next == cells.count,
               "board dropped \(cells.count - next) cells with no way to reach them")
        return rows
    }

    /// The typing levels keep their own bottom row. Enter cannot sit on row
    /// 1 there without displacing a letter, and bottom-right is where every
    /// keyboard puts it anyway.
    ///
    /// The two character-level tools the design drops from the word boards
    /// live here, and only here: single-character delete and ←. A word board
    /// produces whole words, so whole-word delete is the right unit there;
    /// the moment you are spelling something out, one wrong letter is the
    /// likeliest mistake and the cursor has to be able to go back to it.
    /// Four rows, as drawn. The extra height at Large buys taller keys
    /// rather than more of them — at 640pt a row is about 146pt, which is
    /// the easiest target this board has ever had (team decision, 8 Aug).
    ///
    /// The cost is real and is paid in `homeSelection`: 30 word cells for
    /// a 54-word Core, so home has to be curated rather than simply
    /// holding everything.
    ///
    /// Any narrow layout gets 8 rows, not just a phone. Five columns over
    /// four rows holds 16 word cells against home's 36, so an iPad in Split
    /// View or Slide Over was dropping twenty words — silently, the same
    /// way Core lost eleven. Height is the one thing a narrow layout still
    /// has, so it pays with height. The phone has done this all along; the
    /// restriction to `.phone` was the accident.
    var wordBoardRows: Int {
        isCompact ? 8 : 4
    }
}
