import AppKit
import SwiftUI

#if DEBUG
#Preview("Composer - Empty") {
    ChatComposerPreviewHost(text: "")
        .environmentObject(AppModel.preview())
        .frame(width: 620)
        .padding()
}

#Preview("Composer - Draft") {
    ChatComposerPreviewHost(text: PreviewData.shortComposerDraft)
        .environmentObject(AppModel.preview())
        .frame(width: 620)
        .padding()
}

#Preview("Composer - Multiline") {
    ChatComposerPreviewHost(text: PreviewData.longComposerDraft)
        .environmentObject(AppModel.preview())
        .frame(width: 620)
        .padding()
}

#Preview("Composer - Sending") {
    ChatComposerPreviewHost(text: PreviewData.shortComposerDraft)
        .environmentObject(AppModel.preview(isSending: true))
        .frame(width: 620)
        .padding()
}
#endif

struct ChatComposerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.readingTextMetrics) private var textMetrics
    @StateObject private var voiceInput = VoiceInputController()
    @Binding var text: String
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @State private var functionKeyMonitor: Any?
    @State private var returnKeyMonitor: Any?
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
            installReturnKeyMonitor()
        }
        .onDisappear {
            removeFunctionKeyMonitor()
            removeReturnKeyMonitor()
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

    private func installReturnKeyMonitor() {
        guard returnKeyMonitor == nil else { return }
        returnKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isFocused else { return event }
            switch ComposerReturnKeyAction.action(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
            case .send:
                submitIfPossible()
                return nil
            case .insertNewline, .ignore:
                return event
            }
        }
    }

    private func removeFunctionKeyMonitor() {
        guard let functionKeyMonitor else { return }
        NSEvent.removeMonitor(functionKeyMonitor)
        self.functionKeyMonitor = nil
    }

    private func removeReturnKeyMonitor() {
        guard let returnKeyMonitor else { return }
        NSEvent.removeMonitor(returnKeyMonitor)
        self.returnKeyMonitor = nil
    }
}

enum ComposerReturnKeyAction: Equatable {
    case ignore
    case insertNewline
    case send

    static func action(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> ComposerReturnKeyAction {
        guard keyCode == Self.returnKeyCode || keyCode == Self.keypadEnterKeyCode else {
            return .ignore
        }
        if modifierFlags.contains(.shift) {
            return .insertNewline
        }
        if modifierFlags.contains(.command) || modifierFlags.contains(.control) || modifierFlags.contains(.option) {
            return .ignore
        }
        return .send
    }

    private static let returnKeyCode: UInt16 = 36
    private static let keypadEnterKeyCode: UInt16 = 76
}

#if DEBUG
private struct ChatComposerPreviewHost: View {
    @State private var text: String

    init(text: String) {
        _text = State(initialValue: text)
    }

    var body: some View {
        ChatComposerView(text: $text) {}
    }
}
#endif
