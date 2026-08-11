import SwiftUI

/// Turning an API-backed board on, and saying plainly what that costs.
///
/// The switch is here rather than in the keyboard because the keyboard has
/// no network and is never getting one. What this does is ask a model, in
/// the app, about the contexts he already types, and leave the answers in
/// the shared container for the keyboard to look up.
struct AIAssistCard: View {
    @StateObject private var assist = AIAssist()
    @State private var key = ""
    @State private var showingKeyField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { assist.isEnabled },
                                 set: { assist.isEnabled = $0 })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggestions from an AI model")
                        .font(.headline)
                    Text("Asks a model, in this app, what tends to come next and what whole "
                         + "messages he might be writing. The answers are saved for the "
                         + "keyboard to look up offline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("aiAssistToggle")

            if assist.isEnabled {
                privacy
                keyRow
                refreshRow
                statusLine
            }
        }
        .homeCardStyle()
    }

    /// Named in full, because the person this is about cannot read it for
    /// himself and cannot object afterwards.
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What is sent", systemImage: "lock")
                .font(.subheadline.weight(.semibold))
            Text("Only single words from the built-in board, and pairs of those words he has "
                 + "used together — \"want to\", \"go to\". Never a sentence he wrote, never a "
                 + "message he received, never a name learned from the screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("The keyboard itself never connects to anything, with this on or off.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private var keyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(assist.hasKey ? "API key saved" : "No API key",
                      systemImage: assist.hasKey ? "checkmark.circle.fill" : "key")
                    .font(.subheadline)
                    .foregroundStyle(assist.hasKey ? Color.green : Color.secondary)
                Spacer()
                Button(showingKeyField ? "Cancel" : (assist.hasKey ? "Replace" : "Add key")) {
                    showingKeyField.toggle()
                    key = ""
                }
            }
            if showingKeyField {
                HStack {
                    SecureField("sk-ant-…", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button("Save") {
                        assist.setKey(key)
                        key = ""
                        showingKeyField = false
                    }
                    .disabled(key.isEmpty)
                }
                Text("Stored in the device Keychain, in this app only. The keyboard extension "
                     + "cannot read it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var refreshRow: some View {
        HStack {
            Button {
                Task { await assist.refresh() }
            } label: {
                Label("Build suggestions", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!assist.hasKey || isWorking)
            Spacer()
            if case .working(let done, let total) = assist.status {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(width: 120)
            }
        }
    }

    private var isWorking: Bool {
        if case .working = assist.status { return true }
        return false
    }

    @ViewBuilder
    private var statusLine: some View {
        switch assist.status {
        case .idle:
            Text("Nothing built yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .working(let done, let total):
            Text("Asking… \(done) of \(total)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        case .ready(let continuations, let phrases):
            VStack(alignment: .leading, spacing: 2) {
                Text("\(continuations) contexts, \(phrases) with whole messages")
                    .font(.footnote)
                if let generated = assist.table?.generated {
                    Text("Built \(generated.formatted(date: .abbreviated, time: .shortened))"
                         + " by \(assist.table?.source ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("aiAssistStatus")
        }
    }
}
