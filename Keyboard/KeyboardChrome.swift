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
        keys.forEach { $0.view.removeFromSuperview() }
        keys = []
        // A mid-slide rebuild (e.g. clear-all's relabel, a level switch)
        // can shrink the key count while a touch is still moving; a stale
        // highlightedIndex from the old, larger array would then index
        // out of bounds in the next touchMoved restyle.
        highlightedIndex = nil

        // Recomputed here, on every rebuild, so the board is right no
        // matter what caused it — a level change back from the letters
        // keyboard, a re-show, or the sentence simply moving on.
        let context = contextBefore()
        verbForm = smartGrammar ? Grammar.verbForm(after: context) : .base
        verbSubject = smartGrammar ? Grammar.subject(before: context) : nil
        boardSlot = SentenceShape.expected(after: context)
        inflectionBase.removeAll()

        let content = contentRows(for: level)
        contentRowCount = content.count

        // Four fixed controls on the left, three on the right. Enter spans
        // the middle two rows exactly as it does in the reference.
        for (row, definition) in leftEdgeColumn.enumerated() {
            addKey(definition, row: row, col: 0)
        }
        let rightColumn = contentColumns + 1
        addKey(rightEdgeTop, row: 0, col: rightColumn)
        addKey((.ret, goLabel()), row: 1, col: rightColumn, rowSpan: 2)
        addKey((.dismiss, "Hide keyboard"), row: 3, col: rightColumn)

        for (row, cells) in content.enumerated() {
            for (i, cell) in cells.enumerated() {
                if let cell {
                    addKey((cell.action, cell.label), row: row, col: i + 1, colSpan: cell.colSpan, rowSpan: cell.rowSpan)
                }
            }
        }

        updateSuggestions()
        view.setNeedsLayout()
    }

    func addKey(_ def: (KeyAction, String), row: Int, col: Int, colSpan: Int = 1, rowSpan: Int = 1) {
        let keyLabel = KeyView()
        style(keyLabel, action: def.0, label: def.1, highlighted: false)
        trackingView.addSubview(keyLabel)
        keys.append(Key(action: def.0, label: def.1, view: keyLabel, row: row, col: col, colSpan: colSpan, rowSpan: rowSpan))
    }

    /// Which of the three jobs a key does. The role decides its color, and
    /// the color is the only thing the user needs to read to know whether a
    /// key will write, travel, or undo.
    enum KeyRole { case write, navigate, erase, action }

    func role(of action: KeyAction) -> KeyRole {
        switch action {
        case .word, .punct, .char, .space:
            return .write
        case .ret:
            return .action // Enter finishes the message; the design's one blue key
        case .home, .toCategories, .toWords, .toPage, .toLetters, .toNumbers,
             .shift, .cursorLeft, .cursorRight, .dismiss:
            return .navigate
        case .delete, .deleteWord, .clearAll:
            return .erase
        }
    }

    /// The controls the design draws as glyphs rather than words.
    func symbolName(for action: KeyAction) -> String? {
        switch action {
        case .home: return "house.fill"
        case .toCategories: return "square.grid.2x2.fill"
        case .dismiss: return "keyboard.chevron.compact.down"
        case .cursorRight: return "arrow.right"
        case .cursorLeft: return "arrow.left"
        default: return nil
        }
    }

    func symbolImage(_ name: String, tint: UIColor) -> NSAttributedString {
        let pointSize = KeyboardTypography.scaledValue(
            26, textStyle: .title2, traits: traitCollection)
        let configuration = UIImage.SymbolConfiguration(
            pointSize: pointSize, weight: .semibold)
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(tint.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
        return NSAttributedString(attachment: attachment)
    }

    func style(_ label: KeyView, action: KeyAction, label text: String, highlighted: Bool) {
        var background: UIColor
        switch role(of: action) {
        case .write:
            if case .word(let w) = action, let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w] {
                background = Palette.color(for: word.wordClass)
            } else if case .word = action {
                background = Palette.color(for: .social) // a word of the user's own
            } else {
                background = Palette.paper
            }
        case .navigate:
            // Home has no card in the design — it sits directly on the
            // tray, in the tray's own colour, so only the glyph reads.
            background = action == .home ? Palette.board : Palette.navigate
        case .action:
            background = UIColor(white: 0.66, alpha: 1)
        case .erase:
            // Armed clear-all is the one irreversible key; it announces
            // itself in red rather than relying on the label change alone.
            background = isClearAllArmed(action) ? Palette.destructive : Palette.erase
        }

        let foreground: UIColor = action == .ret ? .white : Palette.foreground(on: background)
        label.paint(fill: background, focused: highlighted)
        label.textColor = foreground
        // Phrases have to be allowed to wrap; a control label is one word
        // and should shrink rather than break across lines. Delete word is
        // two, because that is how it is drawn.
        label.lines = role(of: action) == .write ? 3 : (action == .deleteWord ? 2 : 1)
        label.spokenLabel = nil

        // Four controls are glyphs in the design. Drawing them as an image
        // inside the same label keeps every key on one code path; the
        // spoken label carries the name so VoiceOver and the tests read
        // the board a sighted user sees.
        if let symbol = symbolName(for: action) {
            // Home is grey rather than blue: it is not one of the keys that
            // send you somewhere new, it is the way back to where you were.
            let tint = action == .home ? Palette.homeGlyph : foreground
            label.attributedText = symbolImage(symbol, tint: tint)
            label.spokenLabel = text
            return
        }

        switch action {
        case .word(let w):
            if let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w], let emoji = word.emoji {
                // Word on top, symbol underneath, as drawn: the word is
                // what gets typed, and the symbol is the recognition cue.
                let content = NSMutableAttributedString(
                    string: text + "\n", attributes: [
                        .font: KeyboardTypography.font(
                            size: 19, weight: .semibold, textStyle: .title3,
                            traits: traitCollection),
                        .foregroundColor: foreground,
                    ])
                content.append(NSAttributedString(
                    string: emoji, attributes: [
                        .font: KeyboardTypography.font(
                            size: 22, weight: .regular, textStyle: .title2,
                            traits: traitCollection),
                    ]))
                label.attributedText = content
                // The cell is called by its word. Without this a screen
                // reader announces "want raised hands", and the symbol —
                // which exists to be glanced at, not read — ends up being
                // read aloud on every single key.
                label.spokenLabel = text
            } else {
                label.attributedText = nil
                label.font = KeyboardTypography.font(
                    size: 21, weight: .semibold, textStyle: .title3,
                    traits: traitCollection)
                label.text = text
            }
        case .deleteWord:
            // The strike falls on the second line only — it is the word
            // that goes, and the red line is what says so.
            let content = NSMutableAttributedString(
                string: text, attributes: [
                    .font: KeyboardTypography.font(
                        size: 19, weight: .semibold, textStyle: .title3,
                        traits: traitCollection),
                    .foregroundColor: foreground,
                ])
            if let newline = text.range(of: "\n") {
                let start = text.distance(from: text.startIndex, to: newline.upperBound)
                content.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: Palette.destructive,
                ], range: NSRange(location: start, length: (text as NSString).length - start))
            }
            label.attributedText = content
            // Two drawn lines, one spoken name.
            label.spokenLabel = text.replacingOccurrences(of: "\n", with: " ")
        case .punct:
            label.attributedText = nil
            label.font = KeyboardTypography.font(
                size: 30, weight: .semibold, textStyle: .title1,
                traits: traitCollection)
            label.text = text
        case .char:
            label.attributedText = nil
            label.font = KeyboardTypography.font(
                size: 32, weight: .medium, textStyle: .title1,
                traits: traitCollection)
            label.text = level == .letters && shifted ? text.uppercased() : text
        case .home, .toCategories, .toWords, .toPage, .toLetters, .toNumbers, .shift:
            label.attributedText = nil
            label.font = KeyboardTypography.font(
                size: 18, weight: .semibold, textStyle: .headline,
                traits: traitCollection)
            label.text = text
        default:
            label.attributedText = nil
            label.font = KeyboardTypography.font(
                size: 19, weight: .medium, textStyle: .body,
                traits: traitCollection)
            label.text = text
        }
    }

    func isClearAllArmed(_ action: KeyAction) -> Bool {
        if case .clearAll = action { return clearArmedAt != nil }
        return false
    }

    func restyleAll() {
        for (i, key) in keys.enumerated() {
            style(key.view, action: key.action, label: key.label, highlighted: i == highlightedIndex)
        }
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
        // defensive floor for the transient frame before that lands, so
        // it targets the raw preset — not the (possibly inflated)
        // requested height — and converges to the designed size.
        bounds.size.height = min(bounds.height, min(view.bounds.height > 0 ? view.bounds.height : presetHeight, presetHeight))
        guard bounds.width > 0, !keys.isEmpty else { return }
        let yOffset = fullBounds.height - bounds.height
        layoutYOffset = yOffset
        boardBackground.frame = CGRect(
            x: 0, y: yOffset, width: fullBounds.width, height: fullBounds.height - yOffset)
        let inset: CGFloat = 4

        layoutSuggestionBar(in: bounds, yOffset: yOffset, inset: inset)

        let outer: CGFloat = 12
        let gap: CGFloat = 8
        let referenceColumns = isCompact ? 7 : 10
        let edgeCell = max(1, (bounds.width - outer * 2
                              - gap * CGFloat(referenceColumns - 1))
                            / CGFloat(referenceColumns))
        let rightX = outer + CGFloat(referenceColumns - 1) * (edgeCell + gap)
        let contentLeft = outer + edgeCell + gap
        let contentRight = rightX - gap
        let contentCell = max(1, (contentRight - contentLeft
                                 - gap * CGFloat(contentColumns - 1))
                               / CGFloat(contentColumns))

        let availableHeight = bounds.height - topBarHeight
        guard availableHeight > 0 else { return }
        let edgeRowCell: CGFloat
        let contentRowCell: CGFloat
        let gridTop: CGFloat
        if !isCompact && contentRowCount == 4 {
            let fittedRowCell = KeyboardFit.fittedRowHeight(
                preferred: edgeCell,
                availableHeight: availableHeight,
                rows: 4,
                gap: gap,
                outerInset: outer)
            edgeRowCell = fittedRowCell
            contentRowCell = fittedRowCell
            let gridHeight = fittedRowCell * 4 + gap * 3
            gridTop = yOffset + topBarHeight
                + max(outer, (availableHeight - gridHeight) / 2)
        } else {
            edgeRowCell = max(1, (availableHeight - gap * 3 - outer * 2) / 4)
            contentRowCell = max(1, (availableHeight
                                     - gap * CGFloat(contentRowCount - 1) - outer * 2)
                                    / CGFloat(contentRowCount))
            gridTop = yOffset + topBarHeight + outer
        }

        for key in keys {
            let isLeft = key.col == 0
            let isRight = key.col == contentColumns + 1
            let x: CGFloat
            let width: CGFloat
            let rowCell: CGFloat
            if isLeft || isRight {
                x = isLeft ? outer : rightX
                width = edgeCell
                rowCell = edgeRowCell
            } else {
                x = contentLeft + CGFloat(key.col - 1) * (contentCell + gap)
                width = contentCell * CGFloat(key.colSpan) + gap * CGFloat(key.colSpan - 1)
                rowCell = contentRowCell
            }
            key.view.frame = CGRect(
                x: x,
                y: gridTop + CGFloat(key.row) * (rowCell + gap),
                width: width,
                height: rowCell * CGFloat(key.rowSpan) + gap * CGFloat(key.rowSpan - 1))
        }

        recordFit(rowHeight: contentRowCell)
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
            requested: requestedHeight,
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
