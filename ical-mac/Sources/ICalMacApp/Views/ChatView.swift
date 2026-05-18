import ICalMacCore
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle("Assistant")
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @ScaledMetric(relativeTo: .title3) private var bubblePadding = 12
    @ScaledMetric(relativeTo: .title3) private var bubbleSpacing = 6
    @ScaledMetric(relativeTo: .title3) private var sideSpacer = 80
    @ScaledMetric(relativeTo: .title3) private var maxBubbleWidth = 760

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: sideSpacer) }

            VStack(alignment: .leading, spacing: bubbleSpacing) {
                Text(message.role == .user ? "You" : "Cali")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(message.text)
                    .font(.title3)
                    .lineSpacing(3)
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
    @ScaledMetric(relativeTo: .title2) private var composerSpacing = 14
    @ScaledMetric(relativeTo: .title2) private var horizontalPadding = 22
    @ScaledMetric(relativeTo: .title2) private var verticalPadding = 18
    @ScaledMetric(relativeTo: .title2) private var cornerRadius = 24
    @ScaledMetric(relativeTo: .title3) private var accessoryButtonSide = 28
    @ScaledMetric(relativeTo: .headline) private var sendButtonSide = 36

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
                .font(.title2)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit(submitIfPossible)
                .onAppear { isFocused = true }

            HStack(spacing: 12) {
                accessoryButton("Start scheduling", systemImage: "plus") {
                    insertPromptStarter("Schedule ")
                }
                accessoryButton("Refresh calendar context", systemImage: "arrow.clockwise.circle") {
                    Task { await model.refreshCalendar() }
                }
                .disabled(model.isRefreshing)
                accessoryButton("Ask about today", systemImage: "calendar.badge.clock") {
                    insertPromptStarter("What is on my calendar today?")
                }

                Text(model.modelNameLabel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tertiary, in: Capsule())

                Spacer(minLength: 16)

                accessoryButton("Clear draft", systemImage: "xmark.circle") {
                    text = ""
                    isFocused = true
                }
                .disabled(text.isEmpty)

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
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }

    private func accessoryButton(_ help: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .frame(width: accessoryButtonSide, height: accessoryButtonSide)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        onSubmit()
    }

    private func insertPromptStarter(_ starter: String) {
        if trimmedText.isEmpty {
            text = starter
        } else if !text.hasSuffix(" ") {
            text += " "
        }
        isFocused = true
    }
}

private extension AppModel {
    var modelNameLabel: String {
        if modelName.localizedCaseInsensitiveContains("haiku") {
            return "Fast"
        }
        if modelName.localizedCaseInsensitiveContains("sonnet") {
            return "Auto"
        }
        return "Model"
    }
}
