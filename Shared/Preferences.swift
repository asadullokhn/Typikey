import Foundation

/// The two switches a person may need to reach for, in one place.
///
/// Both are read by the keyboard and written by the app, so both are
/// mirrored into the app group and into standard defaults — the keyboard
/// falls back to its own sandbox when Full Access was never granted, and a
/// preference that only works with a permission granted is not a
/// preference.
enum Preferences {

    // MARK: Private mode

    /// Typing works exactly as always; the remembering stops. See
    /// `Privacy` in the keyboard for what that covers.
    private static let privateKey = "privateMode"

    static var privateMode: Bool {
        get { read(privateKey) }
        set { write(newValue, privateKey) }
    }

    static func privateMode(in store: UserDefaults) -> Bool {
        store.bool(forKey: privateKey)
    }

    // MARK: Smart grammar

    /// Whether verb keys relabel to follow the sentence ("I am" → `going`).
    ///
    /// On by default, off by one tap. Every AAC vendor that ships this
    /// feature also ships a way to switch it off, and two of them default
    /// it off: AssistiveWare gates it because changing forms "can cause
    /// confusion and interfere with grammar learning"; PRC-Saltillo advises
    /// "it is best not to turn on Dynamic Labels" for anyone still learning
    /// language, exempting "a literate adult"; Smartbox warns it is
    /// "distracting or confusing… particularly for an early AAC user".
    ///
    /// Sayfullah is literate and, per Gilbert, has no cognitive barrier, so
    /// on is the right default *for him* — but that is a judgement about
    /// one person, and he is the only one who can confirm it. Shipping it
    /// unconditionally would be the one product in the field with no way
    /// out.
    private static let grammarKey = "smartGrammar"

    static var smartGrammar: Bool {
        get { readDefaultingTrue(grammarKey) }
        set { write(newValue, grammarKey) }
    }

    static func smartGrammar(in store: UserDefaults) -> Bool {
        store.object(forKey: grammarKey) as? Bool ?? true
    }

    // MARK: Keyboard size

    /// 0 small, 1 medium, 2 large. It used to be the ⤢ key on the board,
    /// which spent one of the scarcest things here — a grid slot — on a
    /// choice made once and then never again. A slot is a word.
    private static let sizeKey = "sizeIndex"

    static var keyboardSize: Int {
        get {
            (shared?.object(forKey: sizeKey) as? Int)
                ?? (UserDefaults.standard.object(forKey: sizeKey) as? Int)
                ?? 2
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sizeKey)
            shared?.set(newValue, forKey: sizeKey)
        }
    }

    static func keyboardSize(in store: UserDefaults) -> Int {
        (store.object(forKey: sizeKey) as? Int) ?? 2
    }

    // MARK: Storage

    private static var shared: UserDefaults? { UserDefaults(suiteName: ScreenWords.suiteName) }

    private static func read(_ key: String) -> Bool {
        shared?.bool(forKey: key) ?? UserDefaults.standard.bool(forKey: key)
    }

    private static func readDefaultingTrue(_ key: String) -> Bool {
        (shared?.object(forKey: key) as? Bool)
            ?? (UserDefaults.standard.object(forKey: key) as? Bool)
            ?? true
    }

    private static func write(_ value: Bool, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
        shared?.set(value, forKey: key)
    }
}
