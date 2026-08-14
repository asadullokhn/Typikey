import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum CompletionOutcome: Equatable {
    case available(words: [String], latency: Duration)
    case unavailable
    case timedOut
    case failed
    case superseded
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct ModelSuggestion {
    @Guide(description: "One to three short continuations, best first", .maximumCount(3))
    var candidates: [String]
}
#endif

/// On-device phrase completion. All FoundationModels access lives here;
/// the controller only sees requestCompletion/isDegraded. On any
/// unavailability or repeated failure the engine degrades permanently for
/// the session and the keyboard behaves exactly as it did before this
/// feature existed. On the simulator generation always fails, so the
/// degraded path is the tested path.
@MainActor
final class CompletionEngine {

    struct Completion {
        let words: [String]
    }

    private(set) var isDegraded = false
    private(set) var lastOutcome: CompletionOutcome?

    typealias ResponseProvider = @Sendable (String, FieldProfile) async throws -> [String]

    private let debounceInterval: TimeInterval
    private let timeout: TimeInterval
    private var generation = 0
    private var consecutiveFailures = 0
    private var pendingWork: DispatchWorkItem?
    private var inFlight: Task<Void, Never>?
    private let responseProvider: ResponseProvider?

    init(responseProvider: ResponseProvider? = nil,
         debounceInterval: TimeInterval = 0.3,
         timeout: TimeInterval = 2.0) {
        self.responseProvider = responseProvider
        self.debounceInterval = max(0, debounceInterval)
        self.timeout = max(0.001, timeout)
    }

    func requestCompletion(context: String,
                           vocabulary: [String],
                           fieldProfile: FieldProfile = .generic,
                           onResult: @escaping (Completion?) -> Void) {
        pendingWork?.cancel()
        inFlight?.cancel()
        generation += 1
        let token = generation

        guard !isDegraded else { onResult(nil); return }

        let work = DispatchWorkItem { [weak self] in
            // DispatchQueue.main guarantees we're already on the main thread here;
            // assumeIsolated bridges into the MainActor-isolated generate() without
            // an extra async hop.
            MainActor.assumeIsolated {
                self?.generate(context: context, vocabulary: vocabulary,
                               fieldProfile: fieldProfile, token: token, onResult: onResult)
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func deliver(_ completion: Completion?, token: Int,
                         onResult: @escaping (Completion?) -> Void) {
        guard token == generation else { return }
        onResult(completion)
    }

    private func recordFailure(_ outcome: CompletionOutcome) {
        lastOutcome = outcome
        consecutiveFailures += 1
        session = nil
        if consecutiveFailures >= 2 {
            isDegraded = true
        }
    }

    private func beginGeneration(token: Int,
                                 operation: @escaping @Sendable () async throws -> [String],
                                 onResult: @escaping (Completion?) -> Void) {
        let started = ContinuousClock.now
        let watchdogTimeout = timeout
        inFlight = Task { [weak self] in
            guard let self else { return }
            let generator = Task.detached { try await operation() }
            let watchdog = Task.detached {
                try await Task.sleep(nanoseconds: UInt64(watchdogTimeout * 1_000_000_000))
                generator.cancel()
            }
            await withTaskCancellationHandler {
                do {
                    let candidates = try await generator.value
                    watchdog.cancel()
                    guard token == self.generation else {
                        self.lastOutcome = .superseded
                        return
                    }
                    let words = CompletionSanitizer.words(from: candidates)
                    self.consecutiveFailures = 0
                    self.lastOutcome = .available(
                        words: words ?? [], latency: started.duration(to: .now))
                    self.deliver(words.map(Completion.init(words:)),
                                 token: token, onResult: onResult)
                } catch is CancellationError {
                    watchdog.cancel()
                    if Task.isCancelled {
                        self.lastOutcome = .superseded
                        return
                    }
                    self.recordFailure(.timedOut)
                    self.deliver(nil, token: token, onResult: onResult)
                } catch {
                    watchdog.cancel()
                    if Task.isCancelled {
                        self.lastOutcome = .superseded
                        return
                    }
                    self.recordFailure(.failed)
                    self.deliver(nil, token: token, onResult: onResult)
                }
            } onCancel: {
                generator.cancel()
            }
        }
    }

#if canImport(FoundationModels)
    private var session: Any?
    private var sessionProfile: FieldProfile?

    private func generate(context: String, vocabulary: [String], fieldProfile: FieldProfile, token: Int,
                          onResult: @escaping (Completion?) -> Void) {
        if let responseProvider {
            let prompt = makePrompt(context: context, vocabulary: vocabulary, fieldProfile: fieldProfile)
            beginGeneration(token: token, operation: {
                try await responseProvider(prompt, fieldProfile)
            }, onResult: onResult)
            return
        }
        guard #available(iOS 26.0, *) else {
            isDegraded = true
            lastOutcome = .unavailable
            deliver(nil, token: token, onResult: onResult)
            return
        }
        guard SystemLanguageModel.default.availability == .available else {
            isDegraded = true
            lastOutcome = .unavailable
            deliver(nil, token: token, onResult: onResult)
            return
        }

        let prompt = makePrompt(context: context, vocabulary: vocabulary, fieldProfile: fieldProfile)

        let existing = sessionProfile == fieldProfile ? session as? LanguageModelSession : nil
        let liveSession = existing ?? LanguageModelSession(instructions: instructions(for: fieldProfile))
        if existing == nil {
            liveSession.prewarm(promptPrefix: Prompt(promptPrefix(for: fieldProfile)))
        }
        session = liveSession
        sessionProfile = fieldProfile
        beginGeneration(token: token, operation: {
            let response = try await liveSession.respond(
                to: prompt,
                generating: ModelSuggestion.self,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.2,
                    maximumResponseTokens: 48))
            return response.content.candidates
        }, onResult: onResult)
    }
#else
    private var session: Any?

    private func generate(context: String, vocabulary: [String], fieldProfile: FieldProfile, token: Int,
                          onResult: @escaping (Completion?) -> Void) {
        if let responseProvider {
            let prompt = makePrompt(context: context, vocabulary: vocabulary, fieldProfile: fieldProfile)
            beginGeneration(token: token, operation: {
                try await responseProvider(prompt, fieldProfile)
            }, onResult: onResult)
            return
        }
        isDegraded = true
        lastOutcome = .unavailable
        deliver(nil, token: token, onResult: onResult)
    }
#endif

    private func makePrompt(context: String,
                            vocabulary: [String],
                            fieldProfile: FieldProfile) -> String {
        let voice = vocabulary.prefix(40).joined(separator: ", ")
        return """
        \(promptPrefix(for: fieldProfile)) \(String(context.suffix(200)))
        Prefer this person's familiar words when natural: \(voice).
        """
    }

    private func instructions(for fieldProfile: FieldProfile) -> String {
        switch fieldProfile {
        case .conversational:
            return "Suggest up to three short AAC message continuations in the user's language."
        case .search:
            return "Suggest up to three concise search-query continuations in the user's language."
        case .email, .url:
            return "Do not generate prose for structured fields."
        case .generic:
            return "Suggest up to three short natural continuations in the user's language."
        }
    }

    private func promptPrefix(for fieldProfile: FieldProfile) -> String {
        switch fieldProfile {
        case .search: return "Search query so far:"
        default: return "Sentence so far:"
        }
    }
}
