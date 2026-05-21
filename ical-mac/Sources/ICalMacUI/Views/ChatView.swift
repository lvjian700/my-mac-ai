import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("With messages") {
    ChatView()
        .environmentObject(AppModel.preview())
        .frame(width: 700, height: 720)
}

#Preview("Empty") {
    ChatView()
        .environmentObject(AppModel.preview(messages: [
            ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.")
        ]))
        .frame(width: 700, height: 720)
}
#endif

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""
    @ScaledMetric(relativeTo: .body) private var composerHorizontalPadding = 20
    @ScaledMetric(relativeTo: .body) private var composerBottomPadding = 18
    @ScaledMetric(relativeTo: .body) private var transcriptBottomPadding = 150

    var body: some View {
        ZStack(alignment: .bottom) {
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
                                .id("sending")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, transcriptBottomPadding)
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let last = model.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: model.isSending) { _, isSending in
                    guard isSending else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("sending", anchor: .bottom)
                    }
                }
            }

            ComposerView(text: $draft) {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            }
            .padding(.horizontal, composerHorizontalPadding)
            .padding(.bottom, composerBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @ScaledMetric(relativeTo: .body) private var horizontalPadding = 16
    @ScaledMetric(relativeTo: .body) private var verticalPadding = 14
    @ScaledMetric(relativeTo: .body) private var cornerRadius = 24
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
                .frame(maxWidth: .infinity, alignment: .leading)

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
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        onSubmit()
    }
}
