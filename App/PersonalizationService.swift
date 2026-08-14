import CoreLocation
import EventKit
import Foundation

@MainActor
final class PersonalizationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var calendarConsent: Bool
    @Published private(set) var locationConsent: Bool
    @Published private(set) var snapshot: PersonalizationSnapshot?
    @Published private(set) var status = "Not generated"
    @Published private(set) var isRegenerating = false

    private static let calendarConsentKey = "personalizationCalendarConsent"
    private static let locationConsentKey = "personalizationLocationConsent"
    private static let blockedKey = "personalizationBlockedWords"

    private let defaults: UserDefaults
    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()
    private let snapshotStore: PersonalizationSnapshotStore?

    override init() {
        let shared = UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard
        defaults = shared
        calendarConsent = shared.bool(forKey: Self.calendarConsentKey)
        locationConsent = shared.bool(forKey: Self.locationConsentKey)
        if let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ScreenWords.suiteName) {
            snapshotStore = PersonalizationSnapshotStore(directoryURL: directory)
        } else {
            snapshotStore = nil
        }
        super.init()
        locationManager.delegate = self
        snapshot = snapshotStore?.load()
        if let snapshot {
            status = "Updated \(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    func setCalendarConsent(_ enabled: Bool) async {
        if enabled {
            do {
                calendarConsent = try await eventStore.requestFullAccessToEvents()
            } catch {
                calendarConsent = false
                status = "Calendar permission was not granted"
            }
        } else {
            calendarConsent = false
        }
        defaults.set(calendarConsent, forKey: Self.calendarConsentKey)
        await regenerate()
    }

    func setLocationConsent(_ enabled: Bool) async {
        locationConsent = enabled
        defaults.set(enabled, forKey: Self.locationConsentKey)
        if enabled {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        } else {
            await regenerate()
        }
    }

    func regenerate() async {
        guard let snapshotStore else {
            status = "Shared storage is unavailable"
            return
        }
        isRegenerating = true
        defer { isRegenerating = false }

        let blocked = defaults.array(forKey: Self.blockedKey) as? [String] ?? []
        var words: [WeightedWord] = []
        var phrases: [WeightedPhrase] = []

        let myWords = defaults.array(forKey: "myWords") as? [String] ?? []
        words.append(contentsOf: myWords.map { WeightedWord(text: $0, weight: 1) })

        let usage = defaults.dictionary(forKey: "usage") as? [String: Int] ?? [:]
        let maximumUsage = max(1, usage.values.max() ?? 1)
        words.append(contentsOf: usage.map { word, count in
            WeightedWord(
                text: word,
                weight: 0.55 + 0.35 * log1p(Double(count)) / log1p(Double(maximumUsage)))
        })

        if calendarConsent,
           EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let start = Date()
            let end = start.addingTimeInterval(30 * 24 * 60 * 60)
            let events = eventStore.events(matching: eventStore.predicateForEvents(
                withStart: start, end: end, calendars: nil)).prefix(100)
            for event in events {
                let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                phrases.append(WeightedPhrase(text: title, weight: 0.8))
                words.append(contentsOf: tokenWords(in: title).map {
                    WeightedWord(text: $0, weight: 0.75)
                })
            }
        }

        if locationConsent, let label = await currentPlaceLabel() {
            words.append(WeightedWord(text: label, weight: 0.7))
        }

        let next = PersonalizationSnapshot.bounded(
            words: words, phrases: phrases, blockedWords: blocked)
        do {
            try snapshotStore.publish(next)
            snapshot = next
            status = "Updated \(next.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        } catch {
            status = "Could not publish personalization"
        }
    }

    func block(_ word: String) async {
        var blocked = defaults.array(forKey: Self.blockedKey) as? [String] ?? []
        guard !blocked.contains(where: {
            $0.caseInsensitiveCompare(word) == .orderedSame
        }) else { return }
        blocked.append(word)
        defaults.set(blocked, forKey: Self.blockedKey)
        let myWords = (defaults.array(forKey: "myWords") as? [String] ?? []).filter {
            $0.caseInsensitiveCompare(word) != .orderedSame
        }
        defaults.set(myWords, forKey: "myWords")
        await regenerate()
    }

    func unblock(_ word: String) async {
        let blocked = (defaults.array(forKey: Self.blockedKey) as? [String] ?? []).filter {
            $0.caseInsensitiveCompare(word) != .orderedSame
        }
        defaults.set(blocked, forKey: Self.blockedKey)
        await regenerate()
    }

    func deletePublishedData() {
        try? snapshotStore?.delete()
        defaults.removeObject(forKey: Self.blockedKey)
        snapshot = nil
        status = "Published personalization deleted"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationConsent else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            locationConsent = false
            defaults.set(false, forKey: Self.locationConsentKey)
            Task { await regenerate() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locationConsent else { return }
        Task { await regenerate() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if locationConsent { status = "Current place is unavailable" }
    }

    private func currentPlaceLabel() async -> String? {
        guard locationManager.authorizationStatus == .authorizedAlways
                || locationManager.authorizationStatus == .authorizedWhenInUse,
              let location = locationManager.location else { return nil }
        do {
            let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
            return [placemark?.locality, placemark?.administrativeArea]
                .compactMap { $0 }
                .first(where: { !$0.isEmpty })
        } catch {
            return nil
        }
    }

    private func tokenWords(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "’" })
            .map(String.init)
            .filter { $0.count >= 2 && $0.count <= 64 }
    }
}
