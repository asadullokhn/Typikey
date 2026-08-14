import Foundation

enum TextDocumentIdentity {
    private static let selector = NSSelectorFromString("documentIdentifier")

    static func read(from object: AnyObject) -> UUID? {
        guard let object = object as? NSObject,
              object.responds(to: selector),
              let value = object.perform(selector)?.takeUnretainedValue() as? NSUUID else {
            return nil
        }
        return value as UUID
    }
}
