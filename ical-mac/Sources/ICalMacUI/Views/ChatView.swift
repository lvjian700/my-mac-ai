import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("With messages") {
    ChatView()
        .environmentObject(AppModel.preview())
        .frame(width: 700, height: 500)
}

#Preview("Empty") {
    ChatView()
        .environmentObject(AppModel.preview(messages: [
            ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.")
        ]))
        .frame(width: 700, height: 500)
}
#endif

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Assistant", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                        if model.isSending {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let last = model.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            ComposerView(text: $draft) {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            }
            .padding()
        }
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @ScaledMetric(relativeTo: .body) private var bubblePadding = 10
    @ScaledMetric(relativeTo: .body) private var bubbleSpacing = 5
    @ScaledMetric(relativeTo: .body) private var sideSpacer = 80
    @ScaledMetric(relativeTo: .body) private var maxBubbleWidth = 760

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: sideSpacer) }

            VStack(alignment: .leading, spacing: bubbleSpacing) {
                Text(message.role == .user ? "You" : "Cali")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(bubblePadding)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(message.role == .user ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
            }
            .frame(maxWidth: maxBubbleWidth, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer(minLength: sideSpacer) }
        }
    }
}

private struct ComposerView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .body) private var composerSpacing = 10
    @ScaledMetric(relativeTo: .body) private var horizontalPadding = 12
    @ScaledMetric(relativeTo: .body) private var verticalPadding = 10
    @ScaledMetric(relativeTo: .body) private var cornerRadius = 12
    @ScaledMetric(relativeTo: .headline) private var sendButtonSide = 30

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedText.isEmpty && !model.isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: composerSpacing) {
            TextField("Ask anything", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit(submitIfPossible)
                .onAppear { isFocused = true }

            HStack(spacing: 8) {
                Spacer(minLength: 16)

                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Label("Clear Draft", systemImage: "xmark.circle")
                }
                .disabled(text.isEmpty)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Clear draft")

                Button(action: submitIfPossible) {
                    Image(systemName: model.isSending ? "hourglass" : "arrow.up")
                        .font(.headline.weight(.bold))
                        .frame(width: sendButtonSide, height: sendButtonSide)
                        .foregroundStyle(canSubmit ? .white : .secondary.opacity(0.55))
                        .background {
                            Circle()
                                .fill(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.13))
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canSubmit)
                .help("Send")
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        onSubmit()
    }
}
