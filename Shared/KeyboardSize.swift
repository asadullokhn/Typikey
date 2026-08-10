import Foundation
import CoreGraphics

/// The three keyboard heights, defined once.
///
/// They used to be an array of magic numbers private to the keyboard, so
/// the app could offer "Small / Medium / Large" without being able to say
/// what any of them meant — or to draw them. One definition, both sides.
enum KeyboardSize: Int, CaseIterable, Identifiable {
    case small = 0, medium, large

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Height in points.
    ///
    /// The iPad numbers are deliberately large: a dedicated AAC app takes
    /// the whole screen, and Large is what puts a row at roughly 146pt —
    /// taller than a key on the system keyboard. The phone numbers are
    /// small because an iPad preset would swallow an iPhone.
    func height(phone: Bool) -> CGFloat {
        switch (self, phone) {
        case (.small, false): return 360
        case (.medium, false): return 500
        case (.large, false): return 640
        case (.small, true): return 260
        case (.medium, true): return 310
        case (.large, true): return 360
        }
    }

    /// What one row of the four looks like at this size, which is the
    /// number that actually matters to someone aiming at a key.
    func rowHeight(phone: Bool) -> CGFloat {
        (height(phone: phone) - 56) / 4
    }

    static func clamped(_ raw: Int) -> KeyboardSize {
        KeyboardSize(rawValue: min(max(raw, 0), allCases.count - 1)) ?? .large
    }
}
