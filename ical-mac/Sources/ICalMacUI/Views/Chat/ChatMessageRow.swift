import ICalMacCore
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

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 80) }

            VStack(alignment: .leading) {
                ChatMessageText(message: message)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(message.role == .user ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
            .clipShape(ChatBubbleShape(isFromUser: message.role == .user))
            .frame(maxWidth: 760, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user { Spacer(minLength: 80) }
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
