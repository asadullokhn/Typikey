import UIKit

/// The board: the keys, where they sit, how they look, and how a touch
/// becomes a commit.
///
/// One implementation for both targets. The keyboard extension and the
/// app's practice board differ only in what a key *does* — the proxy and
/// its learning on one side, a plain composer on the other — so that is
/// the only thing the host supplies. Everything a user can see or feel
/// lives here, including the three invariants that used to be the
/// keyboard's alone: sliding explores and lifting commits, every point
/// maps to the nearest key, and a repeated key is ignored for half a
/// second.
final class BoardGridView: UIView {

    struct Key {
        let action: KeyAction
        let label: String
        let view: KeyView
        let row: Int
        let col: Int
        let colSpan: Int
        let rowSpan: Int
    }

    /// What the grid needs to know about the board it is drawing.
    struct Geometry {
        /// Columns the pinned edges are measured against, so they keep the
        /// same width whatever the content does.
        var referenceColumns = 10
        var contentColumns = 8
        var contentRowCount = 4
        var isCompact = false
        var bottomInset: CGFloat = 4
        /// Rows are square up to this; a level with more rows gives it up.
        var squareRows = true
    }

    /// The parts of styling only the host can answer.
    struct Context {
        var returnIsActive = false
        var shifted = false
        var isTypingLevel = false
        /// The vocabulary entry behind a label. The host knows about
        /// inflection; the grid does not.
        var word: (String) -> VocabWord? = { _ in nil }
    }

    var geometry = Geometry() { didSet { setNeedsLayout() } }
    var context = Context() { didSet { restyleAll() } }

    var onCommit: (KeyAction) -> Void = { _ in }
    /// Crossing onto a new key while sliding — the board is read by feel.
    var onSlide: () -> Void = {}
    var onTouchEvidence: (TouchEvidence?) -> Void = { _ in }

    private(set) var keys: [Key] = []
    private var highlightedIndex: Int?
    private var lastCommit: (action: KeyAction, at: Date)?
    private var intent = TouchIntentFilter()
    private var now: () -> Date = Date.init
    /// Last laid-out content row height, which the keyboard records as its fit.
    private(set) var rowHeight: CGFloat = 0

    // MARK: Content

    func setKeys(_ placements: [(cell: ContentCell, row: Int, col: Int)]) {
        keys.forEach { $0.view.removeFromSuperview() }
        keys = []
        // A rebuild can shrink the array while a touch is still moving; a
        // stale index would then read out of bounds on the next restyle.
        highlightedIndex = nil
        intent.reset()

        for placement in placements {
            let view = KeyView()
            addSubview(view)
            keys.append(Key(action: placement.cell.action, label: placement.cell.label,
                            view: view, row: placement.row, col: placement.col,
                            colSpan: placement.cell.colSpan, rowSpan: placement.cell.rowSpan))
        }
        restyleAll()
        setNeedsLayout()
    }

    func restyleAll() {
        for (i, key) in keys.enumerated() {
            style(key, highlighted: i == highlightedIndex)
        }
    }

    // MARK: Roles

    enum Role { case write, navigate, erase, action }

    func role(of action: KeyAction) -> Role {
        switch action {
        case .word, .punct, .char, .space: return .write
        case .ret: return .action
        case .home, .toCategories, .toWords, .toPage, .toLetters, .toNumbers,
             .shift, .cursorLeft, .cursorRight, .dismiss: return .navigate
        case .delete, .deleteWord, .clearAll: return .erase
        }
    }

    func fill(for action: KeyAction) -> UIColor {
        switch role(of: action) {
        case .write:
            if case .word(let w) = action {
                return context.word(w).map { Palette.color(for: $0.wordClass) }
                    ?? Palette.color(for: .social) // a word of the user's own
            }
            return Palette.paper
        case .navigate:
            // Home has no card in the design — it sits directly on the
            // tray, in the tray's own colour, so only the glyph reads.
            return action == .home ? Palette.board : Palette.navigate
        case .action:
            return context.returnIsActive ? Palette.action : Palette.commit
        case .erase:
            return Palette.erase
        }
    }
}

// MARK: - Styling

extension BoardGridView {
    func style(_ key: Key, highlighted: Bool) {
        let background = fill(for: key.action)
        let foreground = Palette.foreground(on: background)
        let label = key.view
        let text = key.label

        label.paint(fill: background, focused: highlighted,
                    bordered: key.action != .home)
        label.textColor = foreground
        // Phrases wrap; a control label is one word and shrinks instead.
        // Delete word is two, because that is how it is drawn.
        label.lines = role(of: key.action) == .write ? 3 : (key.action == .deleteWord ? 2 : 1)
        label.spokenLabel = nil

        if let symbol = BoardFrame.symbolName(for: key.action) {
            // Home is grey rather than blue: it is not one of the keys that
            // send you somewhere new, it is the way back to where you were.
            let tint = key.action == .home ? Palette.homeGlyph : foreground
            label.attributedText = symbolImage(symbol, tint: tint)
            label.spokenLabel = text
            return
        }

        switch key.action {
        case .word(let w):
            if let emoji = context.word(w)?.emoji {
                // Word on top, symbol underneath, as drawn: the word is what
                // gets typed, and the symbol is the recognition cue.
                let content = NSMutableAttributedString(string: text + "\n", attributes: [
                    .font: font(19, .semibold, .title3), .foregroundColor: foreground,
                ])
                content.append(NSAttributedString(
                    string: emoji, attributes: [.font: font(22, .regular, .title2)]))
                label.attributedText = content
                // The cell is called by its word. Without this a screen
                // reader announces "want raised hands", and the symbol —
                // which exists to be glanced at — is read aloud every time.
                label.spokenLabel = text
            } else {
                label.attributedText = nil
                label.font = font(21, .semibold, .title3)
                label.text = text
            }
        case .deleteWord:
            // The strike falls on the second line only — it is the word
            // that goes, and the red line is what says so.
            let content = NSMutableAttributedString(string: text, attributes: [
                .font: font(19, .semibold, .title3), .foregroundColor: foreground,
            ])
            if let newline = text.range(of: "\n") {
                let start = text.distance(from: text.startIndex, to: newline.upperBound)
                content.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: Palette.destructive,
                ], range: NSRange(location: start, length: (text as NSString).length - start))
            }
            label.attributedText = content
            label.spokenLabel = text.replacingOccurrences(of: "\n", with: " ")
        case .punct:
            label.attributedText = nil
            label.font = font(30, .semibold, .title1)
            label.text = text
        case .char:
            label.attributedText = nil
            label.font = font(32, .medium, .title1)
            label.text = context.isTypingLevel && context.shifted ? text.uppercased() : text
        case .home, .toCategories, .toWords, .toPage, .toLetters, .toNumbers, .shift:
            label.attributedText = nil
            label.font = font(18, .semibold, .headline)
            label.text = text
        default:
            label.attributedText = nil
            label.font = font(19, .medium, .body)
            label.text = text
        }
    }

    private func font(_ size: CGFloat, _ weight: UIFont.Weight,
                      _ style: UIFont.TextStyle) -> UIFont {
        KeyboardTypography.font(size: size, weight: weight, textStyle: style,
                                traits: traitCollection)
    }

    private func symbolImage(_ name: String, tint: UIColor) -> NSAttributedString {
        let pointSize = KeyboardTypography.scaledValue(
            26, textStyle: .title2, traits: traitCollection)
        let attachment = NSTextAttachment()
        attachment.image = UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold))?
            .withTintColor(tint.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
        return NSAttributedString(attachment: attachment)
    }
}

// MARK: - Layout

extension BoardGridView {
    /// The grid fills its own bounds. Whatever sits above it — a suggestion
    /// bar in the keyboard, the page identity in the app — is the host's,
    /// and the grid never has to know about it.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, !keys.isEmpty else { return }

        let outer = KeyboardFit.outerInset
        let gap = KeyboardFit.gap
        let edgeCell = KeyboardFit.cellWidth(
            boardWidth: bounds.width, columns: geometry.referenceColumns)
        let rightX = outer + CGFloat(geometry.referenceColumns - 1) * (edgeCell + gap)
        let contentLeft = outer + edgeCell + gap
        let contentCell = max(1, (rightX - gap - contentLeft
                                  - gap * CGFloat(geometry.contentColumns - 1))
                                 / CGFloat(geometry.contentColumns))

        let rows = geometry.contentRowCount
        let bottom = geometry.bottomInset
        let edgeRowCell: CGFloat
        let contentRowCell: CGFloat
        let gridTop: CGFloat
        if geometry.squareRows && !geometry.isCompact && rows == 4 {
            let fitted = KeyboardFit.fittedRowHeight(
                preferred: edgeCell * KeyboardFit.maxRowAspect,
                availableHeight: bounds.height, rows: 4, gap: gap,
                verticalInset: outer + bottom)
            edgeRowCell = fitted
            contentRowCell = fitted
            // Sit on the bottom edge: slack goes above the grid rather than
            // into a band below it that reads as the board floating.
            gridTop = max(outer, bounds.height - bottom - (fitted * 4 + gap * 3))
        } else {
            edgeRowCell = max(1, (bounds.height - gap * 3 - outer - bottom) / 4)
            contentRowCell = max(1, (bounds.height - gap * CGFloat(rows - 1)
                                     - outer - bottom) / CGFloat(rows))
            gridTop = outer
        }

        for key in keys {
            let isEdge = key.col == 0 || key.col == geometry.contentColumns + 1
            let x = key.col == 0 ? outer
                  : isEdge ? rightX
                  : contentLeft + CGFloat(key.col - 1) * (contentCell + gap)
            let width = isEdge ? edgeCell
                : contentCell * CGFloat(key.colSpan) + gap * CGFloat(key.colSpan - 1)
            let rowCell = isEdge ? edgeRowCell : contentRowCell
            key.view.frame = CGRect(
                x: x, y: gridTop + CGFloat(key.row) * (rowCell + gap),
                width: width,
                height: rowCell * CGFloat(key.rowSpan) + gap * CGFloat(key.rowSpan - 1))
        }
        rowHeight = contentRowCell
    }
}

// MARK: - Explore-then-commit

extension BoardGridView {
    /// No dead zones: any point maps to the nearest key by centre distance
    /// (invariant 4).
    func keyIndex(at point: CGPoint) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (i, key) in keys.enumerated() {
            if key.view.frame.contains(point) { return i }
            let c = CGPoint(x: key.view.frame.midX, y: key.view.frame.midY)
            let d = hypot(c.x - point.x, c.y - point.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }

    /// Pointer devices — trackpad, Pencil hover, AssistiveTouch — move the
    /// same highlight a finger does, but never commit.
    func highlight(at point: CGPoint) {
        let index = keyIndex(at: point)
        guard index != highlightedIndex else { return }
        if index != nil { onSlide() }
        let old = highlightedIndex
        highlightedIndex = index
        if let old { style(keys[old], highlighted: false) }
        if let index { style(keys[index], highlighted: true) }
    }

    func clearHighlight() {
        guard highlightedIndex != nil else { return }
        highlightedIndex = nil
        restyleAll()
    }

    private func handle(_ sample: TouchSample) {
        let evidence = intent.consume(sample, keyFrames: keys.map { $0.view.frame })
        switch sample.phase {
        case .began, .moved:
            // Crossing onto a new key is the moment worth confirming:
            // sliding is free, so the tick is how the board is read by feel.
            highlight(at: sample.point)
        case .ended:
            onTouchEvidence(evidence)
            let index = keyIndex(at: sample.point)
            highlightedIndex = nil
            restyleAll()
            guard let index else { return }
            commit(keys[index].action)
        case .cancelled:
            onTouchEvidence(nil)
            highlightedIndex = nil
            restyleAll()
        }
    }

    /// Invariant 3: a repeated key inside half a second is a tremor, not a
    /// second word. Erasing and moving the cursor are exempt — those are
    /// the keys a person genuinely does press twice.
    func commit(_ action: KeyAction) {
        if let last = lastCommit, last.action == action,
           now().timeIntervalSince(last.at) < 0.5, !isRepeatable(action) {
            return
        }
        lastCommit = (action, now())
        onCommit(action)
    }

    private func isRepeatable(_ action: KeyAction) -> Bool {
        switch action {
        case .delete, .deleteWord, .clearAll, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, .ended)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, .cancelled)
    }

    private func send(_ touches: Set<UITouch>, _ phase: TouchSample.Phase) {
        guard let touch = touches.first else { return }
        handle(TouchSample(point: touch.location(in: self),
                           timestamp: touch.timestamp, phase: phase))
    }
}
