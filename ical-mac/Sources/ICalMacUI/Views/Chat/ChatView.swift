import SwiftUI

#if DEBUG
#Preview("With messages") {
    ChatView()
        .environmentObject(AppModel.preview(messages: PreviewData.activeChatMessages))
        .frame(width: 700, height: 720)
}

#Preview("Empty") {
    ChatView()
        .environmentObject(AppModel.preview(messages: PreviewData.emptyChatMessages))
        .frame(width: 700, height: 720)
}

#Preview("Sending - Thinking") {
    ChatView()
        .environmentObject(AppModel.preview(messages: PreviewData.sendingChatMessages, isSending: true, assistantLoadingState: .thinking))
        .frame(width: 700, height: 720)
}

#Preview("Sending - Working") {
    ChatView()
        .environmentObject(AppModel.preview(messages: PreviewData.sendingChatMessages, isSending: true, assistantLoadingState: .working("Checking your calendar…")))
        .frame(width: 700, height: 720)
}
#endif

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    private let composerLeadingPadding: CGFloat = 10
    private let composerTrailingPadding: CGFloat = 10
    private let composerBottomPadding: CGFloat = 8

    var body: some View {
        ZStack(alignment: .bottom) {
            ChatTranscriptView(messages: model.messages, isSending: model.isSending, assistantLoadingState: model.assistantLoadingState)

            ChatComposerView(text: $draft) {
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
}
