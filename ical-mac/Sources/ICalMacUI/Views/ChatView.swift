import AppKit
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

    private let composerLeadingPadding: CGFloat = 10
    private let composerTrailingPadding: CGFloat = 10
    private let composerBottomPadding: CGFloat = 8
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
                if message.role != .user {
                    Text("Cali")
                        .font(textMetrics.font(.callout))
                        .foregroundStyle(.secondary)
                }
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
    @StateObject private var voiceInput = VoiceInputController()
    @Binding var text: String
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    @State private var functionKeyMonitor: Any?
    @State private var editorWidth: CGFloat = 0

    private let composerSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 12
    private let topPadding: CGFloat = 10
    private let bottomPadding: CGFloat = 8
    private let cornerRadius: CGFloat = 12
    private let sendButtonSide: CGFloat = 30
    private let voiceButtonSide: CGFloat = 30
    private let controlsSpacing: CGFloat = 6
    private var inputFontSize: CGFloat { textMetrics.value(ReadingTextStyle.body.baseSize) }
    private var minimumInputHeight: CGFloat { max(38, inputFontSize * 2.65) }
    private var maximumInputHeight: CGFloat { max(112, inputFontSize * 8.1) }
    private var editorVerticalInset: CGFloat { max(22, inputFontSize * 1.7) }
    private let editorMeasureHorizontalInset: CGFloat = 8
    private let editorPlaceholderPadding = EdgeInsets(top: 7, leading: 0, bottom: 0, trailing: 0)

    private var editorHeight: CGFloat {
        guard editorWidth > 0 else { return minimumInputHeight }

        let measuringText = text.isEmpty ? " " : text
        let font = NSFont.systemFont(ofSize: inputFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 0
        let measuredWidth = max(1, editorWidth - editorMeasureHorizontalInset)
        let rect = (measuringText as NSString).boundingRect(
            with: NSSize(width: measuredWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
        let measuredHeight = ceil(rect.height) + editorVerticalInset
        return min(maximumInputHeight, max(minimumInputHeight, measuredHeight))
    }

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

    private var canToggleVoiceInput: Bool {
        switch voiceInput.state {
        case .idle, .recording, .failed, .unavailable:
            true
        case .requestingPermission, .transcribing:
            false
        }
    }

    private var voiceButtonHelp: String {
        voiceInput.state.isRecording ? "Click to stop dictation" : "Click to dictate or hold Fn"
    }

    private var shouldShowCaptureControls: Bool {
        switch voiceInput.state {
        case .requestingPermission, .recording:
            true
        case .idle, .transcribing, .unavailable, .failed:
            false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: composerSpacing) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(textMetrics.font(.body))
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: editorHeight,
                        maxHeight: editorHeight,
                        alignment: .topLeading
                    )

                if text.isEmpty {
                    Text("Ask anything")
                        .font(textMetrics.font(.body))
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                        .padding(editorPlaceholderPadding)
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { editorWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in
                            editorWidth = width
                        }
                }
            }

            if shouldShowCaptureControls {
                RecordingControlsView(
                    audioLevels: voiceInput.audioLevels,
                    elapsedSeconds: voiceInput.elapsedSeconds,
                    isPreparing: voiceInput.state == .requestingPermission,
                    canSubmit: canSubmit,
                    stopAction: stopVoiceInput,
                    submitAction: submitIfPossible
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(spacing: controlsSpacing) {
                    VoiceInputInlineStatusView(state: voiceInput.state)

                    Button(action: toggleVoiceInput) {
                        Image(systemName: "mic")
                            .font(.system(size: 16, weight: .regular))
                            .frame(width: voiceButtonSide, height: voiceButtonSide)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canToggleVoiceInput)
                    .help(voiceButtonHelp)

                    Button(action: submitIfPossible) {
                        Image(systemName: model.isSending ? "hourglass" : "arrow.up")
                            .font(.system(size: 16, weight: .regular))
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
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
        .animation(.easeOut(duration: 0.18), value: voiceInput.state)
        .onAppear {
            isFocused = true
            installFunctionKeyMonitor()
        }
        .onDisappear {
            removeFunctionKeyMonitor()
            voiceInput.cancel()
        }
    }

    private func submitIfPossible() {
        guard canSubmit else { return }
        onSubmit()
    }

    private func toggleVoiceInput() {
        guard canToggleVoiceInput else { return }
        if voiceInput.state.isRecording {
            stopVoiceInput()
        } else {
            startVoiceInput()
        }
        isFocused = true
    }

    private func startVoiceInput() {
        voiceInput.handleFunctionKey(isPressed: true) { transcript in
            text = VoiceInputController.appendingTranscript(transcript, to: text)
            isFocused = true
        }
    }

    private func stopVoiceInput() {
        voiceInput.handleFunctionKey(isPressed: false) { transcript in
            text = VoiceInputController.appendingTranscript(transcript, to: text)
            isFocused = true
        }
        isFocused = true
    }

    private func installFunctionKeyMonitor() {
        guard functionKeyMonitor == nil else { return }
        functionKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let isFunctionPressed = event.modifierFlags.contains(.function)
            voiceInput.handleFunctionKey(isPressed: isFunctionPressed) { transcript in
                text = VoiceInputController.appendingTranscript(transcript, to: text)
                isFocused = true
            }
            return event
        }
    }

    private func removeFunctionKeyMonitor() {
        guard let functionKeyMonitor else { return }
        NSEvent.removeMonitor(functionKeyMonitor)
        self.functionKeyMonitor = nil
    }
}

private struct RecordingControlsView: View {
    let audioLevels: [Double]
    let elapsedSeconds: TimeInterval
    let isPreparing: Bool
    let canSubmit: Bool
    var stopAction: () -> Void
    var submitAction: () -> Void

    private let controlsSpacing: CGFloat = 6
    private let buttonSide: CGFloat = 30
    private let timelineHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: controlsSpacing) {
            VoiceTimelineWaveform(levels: audioLevels, isPreparing: isPreparing)
                .frame(maxWidth: .infinity, minHeight: timelineHeight, maxHeight: timelineHeight)

            Text(Self.durationFormatter.string(from: elapsedSeconds) ?? "0:00")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 34, alignment: .trailing)

            Button(action: stopAction) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: buttonSide, height: buttonSide)
                    .foregroundStyle(.primary.opacity(0.78))
                    .background {
                        Circle()
                            .fill(Color.secondary.opacity(0.12))
                        }
                }
                .buttonStyle(.plain)
                .help("Stop dictation")

            Button(action: submitAction) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: buttonSide, height: buttonSide)
                    .foregroundStyle(canSubmit ? .white : .secondary.opacity(0.55))
                    .background {
                        Circle()
                            .fill(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.13))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .help("Send")
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}

private struct VoiceInputInlineStatusView: View {
    let state: VoiceInputState

    private let statusSpacing: CGFloat = 6
    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: statusSpacing) {
            statusSymbol
                .frame(width: iconSize, height: iconSize)

            statusText
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 26, alignment: .center)
    }

    @ViewBuilder
    private var statusSymbol: some View {
        switch state {
        case .requestingPermission, .transcribing:
            ProgressView()
                .controlSize(.small)
        case .unavailable, .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .idle, .recording:
            Color.clear
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .requestingPermission:
            Text("Requesting voice access")
        case .transcribing:
            Text("Transcribing")
        case .unavailable(let message), .failed(let message):
            Text(message)
        case .idle, .recording:
            Text("")
        }
    }
}

private struct VoiceTimelineWaveform: View {
    let levels: [Double]
    let isPreparing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .trailing) {
                    VoiceTimelineBaseline()

                    let spacing: CGFloat = 2.5
                    let visibleLevels = visibleLevels(at: timeline.date)
                    let barWidth = barWidth(levelCount: visibleLevels.count, availableWidth: proxy.size.width, spacing: spacing)

                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(Array(visibleLevels.enumerated()), id: \.offset) { _, level in
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(level > 0.04 ? 0.88 : 0.18))
                                .frame(width: barWidth, height: barHeight(level: level, availableHeight: proxy.size.height))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.12), value: levels)
    }

    private func barWidth(levelCount: Int, availableWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        guard levelCount > 0 else { return 2.4 }
        let totalSpacing = spacing * CGFloat(max(0, levelCount - 1))
        return max(2, (availableWidth - totalSpacing) / CGFloat(levelCount))
    }

    private func visibleLevels(at date: Date) -> [Double] {
        guard isPreparing || !hasLiveLevels else { return levels }
        let count = max(levels.count, 72)
        let phase = date.timeIntervalSinceReferenceDate * 4.8
        return (0..<count).map { index in
            let wave = sin(phase + Double(index) * 0.48)
            let ripple = sin(phase * 1.7 + Double(index) * 0.17)
            return max(0.08, 0.18 + 0.12 * wave + 0.05 * ripple)
        }
    }

    private var hasLiveLevels: Bool {
        levels.contains { $0 > 0.05 }
    }

    private func barHeight(level: Double, availableHeight: CGFloat) -> CGFloat {
        let scaledLevel = max(0.06, min(1, level))
        return max(3, availableHeight * CGFloat(0.18 + scaledLevel * 0.82))
    }
}

private struct VoiceTimelineBaseline: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(Color.secondary.opacity(0.42)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2.2, 4])
            )
        }
    }
}
