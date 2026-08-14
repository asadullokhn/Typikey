import Foundation

struct Case {
    let committed: String
    let expected: String?
    let context: String
    let profile: FieldProfile
}

let cases: [Case] = [
    Case(committed: "teh", expected: "the", context: "I saw", profile: .conversational),
    Case(committed: "freind", expected: "friend", context: "my", profile: .conversational),
    Case(committed: "becuase", expected: "because", context: "I stayed", profile: .generic),
    Case(committed: "thier", expected: "their", context: "it is", profile: .generic),
    Case(committed: "recieve", expected: "receive", context: "I will", profile: .generic),
    Case(committed: "adress", expected: "address", context: "my", profile: .generic),
    Case(committed: "tomorow", expected: "tomorrow", context: "see you", profile: .conversational),
    Case(committed: "homr", expected: "home", context: "go", profile: .conversational),
    Case(committed: "housr", expected: "house", context: "my", profile: .generic),
    Case(committed: "drnik", expected: "drink", context: "I want to", profile: .conversational),
    Case(committed: "eaat", expected: "eat", context: "I want to", profile: .conversational),
    Case(committed: "pleaes", expected: "please", context: "help me", profile: .conversational),
    Case(committed: "scool", expected: "school", context: "go to", profile: .generic),
    Case(committed: "watre", expected: "water", context: "drink", profile: .generic),
    Case(committed: "doctro", expected: "doctor", context: "see the", profile: .generic),
    Case(committed: "mothre", expected: "mother", context: "my", profile: .generic),
    Case(committed: "computre", expected: "computer", context: "the", profile: .generic),
    Case(committed: "juiec", expected: "juice", context: "drink", profile: .generic),
    Case(committed: "form", expected: nil, context: "fill the", profile: .generic),
    Case(committed: "their", expected: nil, context: "it is", profile: .generic),
    Case(committed: "Hafiz", expected: nil, context: "hello", profile: .conversational),
    Case(committed: "NASA", expected: nil, context: "", profile: .generic),
    Case(committed: "1234", expected: nil, context: "", profile: .generic),
    Case(committed: "homr", expected: nil, context: "", profile: .url),
    Case(committed: "freind", expected: nil, context: "", profile: .email),
]

let vocabulary = [
    "the", "friend", "because", "their", "receive", "address", "tomorrow",
    "home", "house", "drink", "eat", "please", "school", "water", "doctor",
    "mother", "computer", "juice", "form", "from", "there", "then", "tea",
]
let frequencies = Dictionary(uniqueKeysWithValues: vocabulary.enumerated().map {
    ($0.element, vocabulary.count - $0.offset + 50)
})
let engine = CorrectionEngine(
    wordFrequencies: frequencies,
    personalWords: ["Hafiz"])

var truePositives = 0
var falsePositives = 0
var falseNegatives = 0
var automaticReplacements = 0
var latencies: [Double] = []

for item in cases {
    let started = ContinuousClock.now
    let decision = engine.evaluate(
        committedWord: item.committed,
        contextBeforeWord: item.context,
        contextAfterWord: "",
        touch: nil,
        fieldProfile: item.profile)
    let duration = started.duration(to: .now).components
    latencies.append(Double(duration.seconds) * 1_000
        + Double(duration.attoseconds) / 1_000_000_000_000_000)

    switch decision {
    case .ignore:
        if item.expected != nil { falseNegatives += 1 }
    case .suggest(_, let replacement, _):
        if replacement.caseInsensitiveCompare(item.expected ?? "") == .orderedSame {
            truePositives += 1
        } else {
            falsePositives += 1
        }
    case .replace(_, let replacement, _):
        automaticReplacements += 1
        if replacement.caseInsensitiveCompare(item.expected ?? "") == .orderedSame {
            truePositives += 1
        } else {
            falsePositives += 1
        }
    }
}

latencies.sort()
let precision = truePositives + falsePositives == 0 ? 0
    : Double(truePositives) / Double(truePositives + falsePositives)
let recall = truePositives + falseNegatives == 0 ? 0
    : Double(truePositives) / Double(truePositives + falseNegatives)
let p95 = latencies[Int(Double(latencies.count - 1) * 0.95)]

print("Correction holdout")
print("  cases: \(cases.count)")
print(String(format: "  suggestion precision: %.1f%%", precision * 100))
print(String(format: "  recall: %.1f%%", recall * 100))
print("  false suggestions: \(falsePositives)")
print("  missed typos: \(falseNegatives)")
print("  automatic replacements: \(automaticReplacements)")
print(String(format: "  reverse-analysis P95: %.3f ms", p95))
