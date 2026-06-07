import ICalMacCore
import SwiftUI

#if DEBUG
#Preview("Transcript - Empty") {
    ChatTranscriptView(messages: PreviewData.emptyChatMessages, isSending: false, assistantLoadingState: .thinking)
        .frame(width: 620, height: 520)
}

#Preview("Transcript - Active") {
    ChatTranscriptView(messages: PreviewData.activeChatMessages, isSending: false, assistantLoadingState: .thinking)
        .frame(width: 620, height: 520)
}

#Preview("Transcript - Sending") {
    ChatTranscriptView(messages: PreviewData.sendingChatMessages, isSending: true, assistantLoadingState: .thinking)
        .frame(width: 620, height: 520)
}

#Preview("Transcript - Working") {
    ChatTranscriptView(messages: PreviewData.sendingChatMessages, isSending: true, assistantLoadingState: .working("Checking your calendar…"))
        .frame(width: 620, height: 520)
}
#endif

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let isSending: Bool
    let assistantLoadingState: AssistantLoadingState

    private var horizontalPadding: CGFloat { 24 }
    private var topPadding: CGFloat { 18 }
    private var bottomPadding: CGFloat { 220 }
    private var spacing: CGFloat { 12 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    LazyVStack(alignment: .leading, spacing: spacing) {
                        ForEach(messages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }

                        if isSending && messages.last?.role != .assistant {
                            ChatLoadingRow(state: assistantLoadingState)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)

                    Color.clear
                        .frame(height: bottomPadding)
                        .id(Self.bottomID)
                }
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isSending) { _, isSending in
                guard isSending else { return }
                scrollToBottom(proxy)
            }
            .onChange(of: messages.last?.text) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomID, anchor: .bottom)
            }
        }
    }

    private static let bottomID = "transcript-bottom"
}
