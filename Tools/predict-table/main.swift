import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Asks a model what comes next, and writes the answer down.
//
// This is the app half of the architecture the keyboard cannot have: a
// real model, running where there is memory for it, producing a table
// small enough for a keyboard extension to read in microseconds. Nothing
// here ships in the keyboard — what ships is the JSON it prints.
//
// Whether that is worth doing is a question with a number, and the number
// comes from Tools/tapcost. Generate a table, measure the corpus with it,
// compare. If the model does not beat the trigrams the keyboard already
// has, we have learned that cheaply and no machinery needs building.
//
//   swift Tools/predict-table/run.sh > model-table.json
//   ./Tools/tapcost/run.sh --file corpus.txt --model-table model-table.json

/// The words worth asking about.
///
/// Not all 400. The board's spare cells and its suggestion bar both key
/// off the last meaningful word, so what matters is what follows a verb,
/// a determiner, a pronoun, or nothing at all. Asking about `banana`
/// spends a model call to improve a sentence nobody writes.
func anchors() -> [String] {
    var wanted: [String] = [""]
    for category in vocabulary {
        for word in category.words where !word.text.contains(" ") {
            switch word.wordClass {
            case .verb, .pronoun, .function, .question: wanted.append(word.text.lowercased())
            default: break
            }
        }
    }
    return Array(Set(wanted)).sorted()
}

// The vocabulary is deliberately NOT in the prompt.
//
// The first version pasted all 400 words in and asked the model to choose
// from them. It answered with the first few words alphabetically — `at,
// and, be, because, about` after everything — because a 400-item list is
// most of the prompt, and list order became the strongest signal in it.
// That table made the corpus WORSE: 1847 taps to 1897.
//
// So the model is asked what actually follows the word, in English, and
// the answer is filtered against the vocabulary afterwards. Constraining
// the output is our job, not the prompt's.

@available(macOS 26.0, *)
func generate() async -> [String: [String]] {
    guard case .available = SystemLanguageModel.default.availability else {
        FileHandle.standardError.write(Data("the on-device model is not available here\n".utf8))
        return [:]
    }

    var table: [String: [String]] = [:]
    let all = anchors()
    for (index, anchor) in all.enumerated() {
        let opening = anchor.isEmpty
            ? "someone is starting a message"
            : "someone has just written the word \"\(anchor)\""
        let prompt = """
        A person who cannot speak is writing a short message to family, a \
        friend, a teacher or an assistant, using a communication board. \
        Right now \(opening).

        Which single words come next most often? Reply with five words, \
        separated by commas, most likely first. No other text.
        """
        // A fresh session per anchor: this is 80 unrelated questions, not
        // a conversation, and letting them accumulate context would make
        // each answer depend on the ones before it.
        let session = LanguageModelSession()
        do {
            // Plain text rather than guided generation: @Generable is a
            // macro, and a macro needs a plugin that a bare swiftc
            // invocation does not load. Parsing a comma-separated line is
            // a fair trade for a tool that has to build in one command.
            let reply = try await session.respond(to: prompt)
            // Anything the board cannot show is not a prediction, it is a
            // word he would have to spell — so it is dropped rather than
            // stored.
            let usable = reply.content
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.lowercased().trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".-*0123456789"))) }
                .filter { vocabIndex[$0] != nil || vocabIndex[$0.capitalized] != nil }
            if !usable.isEmpty { table[anchor] = Array(usable.prefix(5)) }
        } catch {
            FileHandle.standardError.write(Data("  \(anchor): \(error)\n".utf8))
        }
        if (index + 1) % 10 == 0 {
            FileHandle.standardError.write(Data("  \(index + 1)/\(all.count)\n".utf8))
        }
    }
    return table
}

@main
struct PredictTable {
    static func main() async {
        guard #available(macOS 26.0, *) else {
            FileHandle.standardError.write(Data("needs macOS 26\n".utf8))
            return
        }
        let table = await generate()
        guard let json = try? JSONSerialization.data(
            withJSONObject: table, options: [.prettyPrinted, .sortedKeys]) else { return }
        FileHandle.standardOutput.write(json)
        FileHandle.standardError.write(Data("\n\(table.count) anchors written\n".utf8))
    }
}
