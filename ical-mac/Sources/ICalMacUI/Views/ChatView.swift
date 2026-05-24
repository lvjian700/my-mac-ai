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
    @Environment(\.readingTextMetrics) private var textMetrics
    @State private var draft = ""

    private var composerLeadingPadding: CGFloat { textMetrics.layoutValue(10) }
    private var composerTrailingPadding: CGFloat { textMetrics.layoutValue(30) }
    private var composerBottomPadding: CGFloat { textMetrics.layoutValue(10) }
    private var transcriptHorizontalPadding: CGFloat { textMetrics.layoutValue(24) }
    private var transcriptTopPadding: CGFloat { textMetrics.layoutValue(18) }
    private var transcriptBottomPadding: CGFloat { textMetrics.layoutValue(220) }
    private var transcriptSpacing: CGFloat { textMetrics.layoutValue(12) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(alignment: .leading, spacing: transcriptSpacing) {
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
                        .padding(.horizontal, transcriptHorizontalPadding)
                        .padding(.top, transcriptTopPadding)

                        Color.clear
                            .frame(height: transcriptBottomPadding)
                            .id(Self.transcriptBottomID)
                    }
                }
                .onChange(of: model.messages.count) { _, _ in
                    scrollToTranscriptBottom(proxy)
                }
                .onChange(of: model.isSending) { _, isSending in
                    guard isSending else { return }
                    scrollToTranscriptBottom(proxy)
                }
            }

            ComposerView(text: $draft) {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            }
            .padding(.leading, composerLeadingPadding)
            .padding(.trailing, composerTrailingPadding)
            .padding(.bottom, composerBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scrollToTranscriptBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
            }
        }
    }

    private static let transcriptBottomID = "transcript-bottom"
}


private struct MessageRow: View {
    let message: ChatMessage
    @Environment(\.readingTextMetrics) private var textMetrics

    private var bubblePadding: CGFloat { textMetrics.layoutValue(10) }
    private var bubbleSpacing: CGFloat { textMetrics.layoutValue(5) }
    private var sideSpacer: CGFloat { textMetrics.layoutValue(80) }
    private var maxBubbleWidth: CGFloat { textMetrics.layoutValue(760) }

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: sideSpacer) }

            VStack(alignment: .leading, spacing: bubbleSpacing) {
                Text(message.role == .user ? "You" : "Cali")
                    .font(textMetrics.font(.callout))
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .font(textMetrics.font(.body))
                    .textSelection(.enabled)
            }
            .padding(bubblePadding)
            .background {
                RoundedRectangle(cornerRadius: textMetrics.layoutValue(8))
                    .fill(message.role == .user ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
            }
            .frame(maxWidth: maxBubbleWidth, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer(minLength: sideSpacer) }
        }
    }
}

private struct ComposerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    private var composerSpacing: CGFloat { textMetrics.layoutValue(10) }
    private var horizontalPadding: CGFloat { textMetrics.layoutValue(16) }
    private var verticalPadding: CGFloat { textMetrics.layoutValue(12) }
    private var cornerRadius: CGFloat { textMetrics.layoutValue(12) }
    private var sendButtonSide: CGFloat { textMetrics.layoutValue(30) }
    private var controlsSpacing: CGFloat { textMetrics.layoutValue(8) }
    private var controlsLeadingSpace: CGFloat { textMetrics.layoutValue(16) }

    private var composerFill: Color {
        isFocused ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .controlBackgroundColor)
    }

    private var composerStroke: Color {
        isFocused ? Color.accentColor.opacity(0.20) : Color(nsColor: .separatorColor).opacity(0.30)
    }

    private var composerShadowOpacity: Double {
        isFocused ? 0.10 : 0.06
    }

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
                .font(textMetrics.font(.body))
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit(submitIfPossible)
                .onAppear { isFocused = true }
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: controlsSpacing) {
                Spacer(minLength: controlsLeadingSpace)

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
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(composerFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(composerStroke, lineWidth: isFocused ? 1 : 0.75)
        }
        .shadow(color: .black.opacity(composerShadowOpacity), radius: isFocused ? 18 : 12, x: 0, y: 6)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        onSubmit()
    }
}
