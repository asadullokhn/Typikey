import UIKit

extension FieldProfile {
    init(keyboardType: UIKeyboardType?,
         returnKeyType: UIReturnKeyType?,
         textContentType: UITextContentType?) {
        switch keyboardType {
        case .URL?:
            self = .url
        case .emailAddress?:
            self = .email
        case .webSearch?:
            self = .search
        default:
            if textContentType == .URL {
                self = .url
            } else if textContentType == .emailAddress {
                self = .email
            } else if returnKeyType == .search {
                self = .search
            } else if returnKeyType == .send {
                self = .conversational
            } else {
                self = .generic
            }
        }
    }

    init(traits: any UITextInputTraits) {
        self.init(
            keyboardType: traits.keyboardType,
            returnKeyType: traits.returnKeyType,
            textContentType: traits.textContentType)
    }
}
