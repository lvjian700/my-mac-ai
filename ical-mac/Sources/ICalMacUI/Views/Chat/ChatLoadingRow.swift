import SwiftUI

public enum AssistantLoadingState: Equatable {
    case thinking
    case working(String)
}

struct ChatLoadingRow: View {
    let state: AssistantLoadingState

    @Environment(\.readingTextMetrics) private var textMetrics

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            bubbleContent
                .font(textMetrics.font(.body))
                .background(Color.secondary.opacity(0.10))
                .clipShape(ChatBubbleShape(isFromUser: false))
                .frame(minWidth: 60, maxWidth: textMetrics.layoutValue(760), alignment: .leading)
                .animation(.easeInOut(duration: 0.22), value: state)
            Spacer()
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch state {
        case .thinking:
            TypingDotsView()
                .padding(.horizontal, textMetrics.layoutValue(14))
                .padding(.vertical, textMetrics.layoutValue(12))
        case .working(let status):
            Text(status)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.horizontal, textMetrics.layoutValue(14))
                .padding(.vertical, textMetrics.layoutValue(10))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 0.75 : 0.2)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

#if DEBUG
#Preview("Thinking") {
    ChatLoadingRow(state: .thinking)
        .padding()
        .frame(width: 620)
}

#Preview("Working") {
    ChatLoadingRow(state: .working("Checking your calendar…"))
        .padding()
        .frame(width: 620)
}

#Preview("Retrying") {
    ChatLoadingRow(state: .working("Retrying 1/3…"))
        .padding()
        .frame(width: 620)
}

#Preview("Loading Flow") {
    LoadingFlowPreview()
        .padding()
        .frame(width: 620, height: 80)
}

#Preview("Retry Flow") {
    RetryFlowPreview()
        .padding()
        .frame(width: 620, height: 80)
}

@MainActor
private struct LoadingFlowPreview: View {
    @State private var state: AssistantLoadingState = .thinking

    var body: some View {
        ChatLoadingRow(state: state)
            .task {
                let steps: [(AssistantLoadingState, Duration)] = [
                    (.thinking, .seconds(1.4)),
                    (.working("Checking your calendar…"), .seconds(1.2)),
                    (.working("Finding a free slot…"), .seconds(1.0)),
                    (.working("Creating event…"), .seconds(0.9)),
                ]
                while !Task.isCancelled {
                    for (nextState, delay) in steps {
                        withAnimation { state = nextState }
                        try? await Task.sleep(for: delay)
                    }
                }
            }
    }
}

@MainActor
private struct RetryFlowPreview: View {
    @State private var state: AssistantLoadingState = .thinking

    var body: some View {
        ChatLoadingRow(state: state)
            .task {
                let steps: [(AssistantLoadingState, Duration)] = [
                    (.thinking, .seconds(1.2)),
                    (.working("Retrying 1/3…"), .seconds(1.0)),
                    (.working("Retrying 2/3…"), .seconds(1.0)),
                    (.working("Retrying 3/3…"), .seconds(1.0)),
                ]
                while !Task.isCancelled {
                    for (nextState, delay) in steps {
                        withAnimation { state = nextState }
                        try? await Task.sleep(for: delay)
                    }
                }
            }
    }
}
#endif
