import Foundation
import CoreGraphics

/// The board's geometry, and what the system actually granted it.
///
/// iOS is free to hand a keyboard extension less height than it asks for,
/// and the only place that number exists is inside the extension — so it is
/// recorded here for the app to read. Geometry only, never text, which is
/// why it is recorded in private mode too.
enum KeyboardFit {
    private static let key = "keyboardFit"

    // MARK: Spacing, defined once

    static let outerInset: CGFloat = 12
    static let gap: CGFloat = 8
    /// The suggestion bar above the grid.
    static let barHeight: CGFloat = 56
    /// The board is always four rows. Levels needing more (abc, 123) fit
    /// them into the same height rather than asking for a taller keyboard.
    static let rows = 4

    // MARK: How tall the board asks to be

    /// The most of the screen the drawn board may take. There is no size
    /// setting — the board is always as big as it can be — so this is the
    /// one number that decides how much of the screen it claims, and the
    /// only place to turn it up or down. Measured on a 13-inch iPad: 0.80
    /// left the host app a strip too thin to read, 0.72 keeps rows at
    /// roughly 113pt, still nearly twice the system keyboard's.
    static let targetFraction: CGFloat = 0.72

    /// How much taller than it is wide a key may become. At 1 the keys are
    /// square, which is the team's design: a word cell reads as a tile, and
    /// a column of ten tall rectangles does not. The board's height follows
    /// from it — the cell width is fixed by the column count, so this is
    /// what decides how tall four rows want to be.
    static let maxRowAspect: CGFloat = 1.0

    /// Margin under the last row. The sides use `outerInset`; the bottom
    /// uses only the home-indicator strip, so the board reads as sitting on
    /// the screen's edge rather than floating above it.
    static func bottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom, 4)
    }

    static func cellWidth(boardWidth: CGFloat, columns: Int) -> CGFloat {
        max(1, (boardWidth - outerInset * 2 - gap * CGFloat(columns - 1))
               / CGFloat(columns))
    }

    /// The tallest board worth asking for at this width. More than the rows
    /// can use would only add margin, since the grid centres itself in
    /// whatever it is given.
    static func targetHeight(
        boardWidth: CGFloat,
        columns: Int,
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        let row = cellWidth(boardWidth: boardWidth, columns: columns) * maxRowAspect
        let wanted = barHeight + outerInset + bottomInset(safeAreaBottom: safeAreaBottom)
            + gap * CGFloat(rows - 1) + row * CGFloat(rows)
        return min(wanted, screenHeight * targetFraction)
    }

    /// `verticalInset` is the total taken above and below the grid, not one
    /// side doubled — the bottom margin is deliberately smaller than the top.
    static func fittedRowHeight(
        preferred: CGFloat,
        availableHeight: CGFloat,
        rows: Int,
        gap: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        let occupiedBySpacing = verticalInset + gap * CGFloat(rows - 1)
        let heightLimited = (availableHeight - occupiedBySpacing) / CGFloat(rows)
        return max(1, min(preferred, heightLimited))
    }

    struct Reading {
        let requested: CGFloat
        let granted: CGFloat
        let rowHeight: CGFloat
        let rows: Int
        /// Word cells the board holds once the controls have taken theirs.
        /// The app needs it to say whether My Words still fits.
        let slots: Int

        /// The board is drawn bottom-aligned inside whatever it is given.
        /// A pixel of slack absorbs rounding.
        var fits: Bool { granted + 1 >= rowHeight * CGFloat(rows) + barHeight }
        var barHeight: CGFloat { KeyboardFit.barHeight }
        var shortfall: CGFloat { max(0, requested - granted) }
    }

    static func record(_ reading: Reading, in store: UserDefaults) {
        store.set([
            "requested": Double(reading.requested),
            "granted": Double(reading.granted),
            "rowHeight": Double(reading.rowHeight),
            "rows": reading.rows,
            "slots": reading.slots,
        ], forKey: key)
    }

    static func read(from store: UserDefaults) -> Reading? {
        guard let raw = store.dictionary(forKey: key),
              let requested = raw["requested"] as? Double,
              let granted = raw["granted"] as? Double,
              let rowHeight = raw["rowHeight"] as? Double,
              let rows = raw["rows"] as? Int
        else { return nil }
        return Reading(requested: CGFloat(requested), granted: CGFloat(granted),
                       rowHeight: CGFloat(rowHeight), rows: rows,
                       slots: raw["slots"] as? Int ?? 0)
    }
}
