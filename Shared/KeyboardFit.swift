import Foundation
import CoreGraphics

/// What the system actually handed the keyboard, so the app can answer
/// "does the whole board fit?" instead of anyone squinting at a photo of a
/// screen. iOS is free to grant a keyboard extension less height than it
/// asks for, and the only place that number exists is inside the extension.
///
/// Geometry only — no text, no counts of anything typed — which is why it
/// is recorded even in private mode. That promise is about what he says,
/// not about how tall a row is.
enum KeyboardFit {
    private static let key = "keyboardFit"

    struct Reading {
        let requested: CGFloat
        let granted: CGFloat
        let rowHeight: CGFloat
        let rows: Int
        /// Word cells the board actually holds, once the controls have
        /// taken theirs. The app needs it to say whether everything in My
        /// Words still fits.
        let slots: Int

        /// The board is drawn bottom-aligned inside whatever it is given,
        /// so it fits exactly when the rows plus the suggestion bar are no
        /// taller than the grant. A pixel of slack absorbs rounding.
        var fits: Bool { granted + 1 >= rowHeight * CGFloat(rows) + barHeight }
        var barHeight: CGFloat { 56 }
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
