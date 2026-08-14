import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct EngineStatusSection: View {
    @State private var status = "Checking…"
    @State private var statusSymbol = "hourglass"
    @State private var probeResult: String?
    @State private var probing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phrase completion")
                .font(.headline)
            Label(status, systemImage: statusSymbol)
            if let probeResult {
                Label(probeResult, systemImage: "stopwatch")
            }
            Button(probing ? "Generating…" : "Test generation") { runProbe() }
                .disabled(probing || statusSymbol != "checkmark.circle")
        }
        .homeCardStyle()
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                status = "On-device model available"
                statusSymbol = "checkmark.circle"
            case .unavailable(let reason):
                status = "Model unavailable: \(String(describing: reason)). Check Settings → Apple Intelligence & Siri."
                statusSymbol = "exclamationmark.triangle"
            @unknown default:
                status = "Model availability unknown"
                statusSymbol = "questionmark.circle"
            }
        } else {
            status = "Needs iPadOS 26 — the keyboard falls back to word prediction"
            statusSymbol = "info.circle"
        }
#else
        status = "FoundationModels not in this SDK"
        statusSymbol = "info.circle"
#endif
    }

    private func runProbe() {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        probing = true
        probeResult = nil
        Task {
            do {
                let coldSession = LanguageModelSession()
                let coldStart = Date()
                let cold = try await coldSession.respond(
                    to: "Continue naturally with at most five words: I want to").content
                let coldMs = Int(Date().timeIntervalSince(coldStart) * 1000)

                let prewarmedSession = LanguageModelSession()
                prewarmedSession.prewarm(
                    promptPrefix: Prompt("Continue naturally with at most five words:"))
                let prewarmedStart = Date()
                _ = try await prewarmedSession.respond(
                    to: "Continue naturally with at most five words: I want to").content
                let prewarmedMs = Int(Date().timeIntervalSince(prewarmedStart) * 1000)

                let warmStart = Date()
                _ = try await prewarmedSession.respond(
                    to: "Continue naturally with at most five words: today we will").content
                let warmMs = Int(Date().timeIntervalSince(warmStart) * 1000)
                await MainActor.run {
                    probeResult = "cold \(coldMs) ms, prewarmed \(prewarmedMs) ms, warm \(warmMs) ms — \"\(cold.prefix(40))\""
                    probing = false
                }
            } catch {
                await MainActor.run {
                    probeResult = "Generation failed: \(String(describing: error))"
                    probing = false
                }
            }
        }
#endif
    }
}
