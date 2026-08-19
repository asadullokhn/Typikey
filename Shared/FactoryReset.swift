import Foundation

/// Putting Typikey back the way it shipped.
///
/// Everything either target has learned or been given lives in the App
/// Group, mirrored into standard defaults for the case where Full Access
/// was never granted. Reset has to clear both or it half-works — and a
/// half-cleared reset is worse than none, because the person doing it
/// believes it worked.
///
/// The group is cleared as a whole domain rather than key by key. A list of
/// keys is a list somebody has to remember to add to, and the store that
/// gets forgotten is always the one nobody noticed surviving. Standard
/// defaults are named, because that domain is not ours alone.
enum FactoryReset {
    static let suiteName = "group.com.asadullokh.ch5.typikey"

    /// The preferences the app mirrors outside the group, plus the flag
    /// that decides whether the guide is shown.
    static let mirroredKeys = [
        "privateMode", "smartGrammar", "boardFollowsSentence", "onboardingSeen",
    ]

    /// Posted once everything is gone, so anything holding a loaded copy
    /// can drop it. Without this the app keeps showing boards that no
    /// longer exist anywhere.
    static let didReset = Notification.Name("typikeyDidReset")

    static func run() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        UserDefaults(suiteName: suiteName)?.synchronize()
        for key in mirroredKeys { UserDefaults.standard.removeObject(forKey: key) }
        NotificationCenter.default.post(name: didReset, object: nil)
    }
}
