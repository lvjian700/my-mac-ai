import SwiftUI

#if DEBUG
#Preview("Messages - Roles") {
    VStack(spacing: 12) {
        ChatMessageRow(message: PreviewData.userChatMessage)
        ChatMessageRow(message: PreviewData.assistantChatMessage)
    }
    .padding()
    .frame(width: 620)
}

#Preview("Messages - Markdown") {
    ChatMessageRow(message: PreviewData.markdownAssistantChatMessage)
        .padding()
        .frame(width: 620)
}
#endif

struct ChatMessageRow: View {
    let message: ChatMessage

    @Environment(\.readingTextMetrics) private var textMetrics

    private var bubblePadding: CGFloat { textMetrics.layoutValue(10) }
    private var sideSpacer: CGFloat { textMetrics.layoutValue(80) }
    private var maxBubbleWidth: CGFloat { textMetrics.layoutValue(760) }

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: sideSpacer) }

            VStack(alignment: .leading) {
                ChatMessageText(message: message)
                    .font(textMetrics.font(.body))
                    .textSelection(.enabled)
            }
            .padding(bubblePadding)
            .background(message.role == .user ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
            .clipShape(ChatBubbleShape(isFromUser: message.role == .user))
            .frame(maxWidth: maxBubbleWidth, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer(minLength: sideSpacer) }
        }
    }
}

private struct ChatMessageText: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .assistant, let attributedText = markdownText {
            Text(attributedText)
        } else {
            Text(message.text)
        }
    }

    private var markdownText: AttributedString? {
        try? AttributedString(
            markdown: message.text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }
}
