import UIKit
import NaturalLanguage

/// Turning cells into views, and putting them where they go.
///
/// Nothing here decides what the board says; it draws whatever
/// `contentRows` produced and measures the result. The split matters
/// because a change to how a key looks should never be able to change
/// what a key is.

extension KeyboardViewController {
    // MARK: Building

    /// The chips share the bar between however many there are.
    ///
    /// Fixed thirds wasted the bar whenever there were fewer than three,
    /// and made a whole rephrased sentence unhittable — a third of the
    /// width at 15pt is a target this user cannot reliably land on, which
    /// is the entire problem the keyboard exists to solve. One suggestion
    /// now spans the bar; two take half each.
    ///
    /// The bar is the one place in the keyboard where things are allowed
    /// to move (invariant 6 puts prediction here precisely so the grid
    /// never has to), but this does mean a chip's position depends on how
    /// many there are. Worth raising with the team: bigger targets against
    /// slightly less predictable ones.
    func layoutSuggestionBar(in bounds: CGRect, yOffset: CGFloat, inset: CGFloat) {
        let shown = max(1, suggestionButtons.filter { !$0.isHidden }.count)
        let slotWidth = (bounds.width - inset * 2) / CGFloat(shown)
        for (i, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(
                x: inset + CGFloat(i) * slotWidth + 3, y: yOffset + inset,
                width: slotWidth - 6, height: topBarHeight - inset * 2)
        }
    }

    func buildSuggestionBar() {
        for i in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = KeyboardTypography.font(
                size: 23, weight: .semibold, textStyle: .title2,
                traits: traitCollection)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            // Down to 12pt: a rephrasing is a sentence, not a word, and
            // reading it is what makes accepting it a decision rather
            // than a gamble.
            button.titleLabel?.minimumScaleFactor = 0.52
            // Filled pill, not tinted text: a suggestion is a target to be
            // hit, so it has to look as tappable as a key.
            button.backgroundColor = Palette.suggestionFill
            button.setTitleColor(Palette.action, for: .normal)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = Palette.suggestionBorder.cgColor
            button.tag = i
            button.accessibilityIdentifier = "typikeySuggestion\(i)"
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            trackingView.addSubview(button)
            suggestionButtons.append(button)
        }
    }

    func buildKeys() {
        resetTouchIntent()

        // Recomputed here, on every rebuild, so the board is right no
        // matter what caused it — a level change back from the letters
        // keyboard, a re-show, or the sentence simply moving on.
        let context = contextBefore()
        returnIsActive = textDocumentProxy.hasText
        verbForm = smartGrammar ? Grammar.verbForm(after: context) : .base
        verbSubject = smartGrammar ? Grammar.subject(before: context) : nil
        boardSlot = SentenceShape.expected(after: context)
        inflectionBase.removeAll()

        let content = contentRows(for: level)
        contentRowCount = content.count

        // Four fixed controls on the left, three on the right. Enter spans
        // the middle two rows exactly as it does in the reference.
        var placements: [(cell: ContentCell, row: Int, col: Int)] = []
        for (row, cell) in leftEdgeColumn.enumerated() {
            placements.append((cell, row, 0))
        }
        let rightColumn = contentColumns + 1
        placements.append((rightEdgeTop, 0, rightColumn))
        placements.append((BoardFrame.rightEnter(label: goLabel()), 1, rightColumn))
        placements.append((BoardFrame.rightDismiss, 3, rightColumn))
        for (row, cells) in content.enumerated() {
            for (i, cell) in cells.enumerated() where cell != nil {
                placements.append((cell!, row, i + 1))
            }
        }

        syncBoardContext()
        boardGrid.geometry = boardGeometry
        boardGrid.setKeys(placements)

        updateSuggestions()
        view.setNeedsLayout()
    }

    var boardGeometry: BoardGridView.Geometry {
        BoardGridView.Geometry(
            referenceColumns: referenceColumns,
            contentColumns: contentColumns,
            contentRowCount: contentRowCount,
            isCompact: isCompact,
            bottomInset: KeyboardFit.bottomInset(safeAreaBottom: view.safeAreaInsets.bottom))
    }



    func restyleAll() {
        syncBoardContext()
        boardGrid.restyleAll()
    }

    func refreshAppearance() {
        boardBackground.backgroundColor = isPrivate ? Palette.privateBoard : Palette.board
        for button in suggestionButtons {
            button.backgroundColor = Palette.suggestionFill
            button.setTitleColor(Palette.action, for: .normal)
            button.titleLabel?.font = KeyboardTypography.font(
                size: 23, weight: .semibold, textStyle: .title2,
                traits: traitCollection)
            button.layer.borderColor = Palette.suggestionBorder
                .resolvedColor(with: traitCollection).cgColor
        }
        restyleAll()
    }

    // MARK: Layout

    func layoutKeys() {
        let fullBounds = trackingView.bounds
        var bounds = fullBounds
        // viewDidLayoutSubviews compensates the height REQUEST when the
        // system grants less than we asked for; this clamp is only a
        // defensive floor for the transient frame before that lands.
        let target = targetHeight
        bounds.size.height = min(bounds.height, min(view.bounds.height > 0 ? view.bounds.height : target, target))
        guard bounds.width > 0, !boardGrid.keys.isEmpty else { return }
        let yOffset = fullBounds.height - bounds.height
        layoutYOffset = yOffset
        // Paint through the bottom safe area too. The system parks our view
        // above the home-indicator strip and leaves that strip to us;
        // unpainted, the app shows through it and the board reads as
        // floating above the screen edge rather than sitting on it.
        boardBackground.frame = CGRect(
            x: 0, y: yOffset, width: fullBounds.width,
            height: fullBounds.height - yOffset + view.safeAreaInsets.bottom)

        layoutSuggestionBar(in: bounds, yOffset: yOffset, inset: 4)

        boardGrid.geometry = boardGeometry
        boardGrid.frame = CGRect(
            x: 0, y: yOffset + topBarHeight,
            width: bounds.width, height: max(0, bounds.height - topBarHeight))
        boardGrid.layoutIfNeeded()

        recordFit(rowHeight: boardGrid.rowHeight)
        // Every key exists and is placed: this is the most memory the
        // keyboard ever holds, so it is the moment worth recording.
        Footprint.recordPeak(in: store)
    }

    /// Publishes the height the system actually granted, so the app can say
    /// whether the whole board fits. Only the extension can see this
    /// number, and "is the bottom row cut off?" is otherwise a question
    /// nobody can answer without photographing a screen.
    ///
    /// Written straight to the store rather than through `learn`: this is
    /// geometry, not something he said, and private mode's promise is about
    /// the latter. Recorded only when it changes, since layout runs often.
    func recordFit(rowHeight: CGFloat) {
        let reading = KeyboardFit.Reading(
            requested: targetHeight,
            granted: view.bounds.height,
            rowHeight: rowHeight,
            rows: contentRowCount,
            slots: wordSlots)
        let signature = "\(Int(reading.requested))|\(Int(reading.granted))|\(Int(reading.rowHeight))|\(reading.rows)|\(reading.slots)"
        guard signature != lastFitSignature else { return }
        lastFitSignature = signature
        KeyboardFit.record(reading, in: store)
    }
}

// MARK: - The shared board

extension KeyboardViewController {
    /// Everything the grid cannot know: what a key does, what a word is,
    /// and how a slide should feel.
    func configureBoardGrid() {
        boardGrid.isMultipleTouchEnabled = false
        boardGrid.onCommit = { [weak self] action in self?.commit(action) }
        boardGrid.onSlide = { [weak self] in self?.haptics.slidToNewKey() }
        boardGrid.onTouchEvidence = { [weak self] evidence in
            self?.lastTouchEvidence = evidence
        }
        boardGrid.context.word = { [weak self] label in
            guard let self else { return nil }
            return vocabIndex[label] ?? vocabIndex[inflectionBase[label] ?? label]
        }
    }

    /// Pushes the host-owned parts of styling down before a restyle.
    func syncBoardContext() {
        boardGrid.context.returnIsActive = returnIsActive
        boardGrid.context.shifted = shifted
        boardGrid.context.isTypingLevel = !isWordLevel
    }
}

extension KeyboardViewController {
    /// Repaints the return key alone when the field gains or loses text. A
    /// full rebuild would drop the highlight mid-slide.
    func syncReturnKey() {
        let active = textDocumentProxy.hasText
        guard active != returnIsActive else { return }
        returnIsActive = active
        syncBoardContext()
        boardGrid.restyleAll()
    }
}
