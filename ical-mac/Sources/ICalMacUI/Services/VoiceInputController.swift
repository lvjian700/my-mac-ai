import Foundation
@preconcurrency import AVFoundation
@preconcurrency import Speech

enum VoiceInputState: Equatable {
    case idle
    case requestingPermission
    case recording
    case transcribing
    case unavailable(String)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .requestingPermission, .recording, .transcribing:
            true
        case .idle, .unavailable, .failed:
            false
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

@MainActor
protocol VoiceTranscribing: AnyObject {
    var levelHandler: (@MainActor @Sendable (Double) -> Void)? { get set }
    var bufferHandler: (@Sendable (AVAudioPCMBuffer, TimeInterval) -> Void)? { get set }

    func requestAuthorization() async throws
    func start() throws
    func finish() async throws -> String
    func cancel()
}

@MainActor
final class VoiceInputController: ObservableObject {
    @Published private(set) var state: VoiceInputState = .idle
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var audioLevel: Double = 0
    @Published private(set) var audioLevels: [Double]

    var debugCapture: VoiceDebugCapture?
    var settings: VoiceInputSettings?

    private let transcriber: VoiceTranscribing
    private let now: () -> Date
    private let startDelay: Duration
    private let retainedLevelCount: Int
    private var isFunctionKeyDown = false
    private var recordingStartedAt: Date?
    private var timerTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var ambientNoiseFloor = 0.03
    private var smoothedAudioLevel = 0.0

    init(
        transcriber: VoiceTranscribing = AppleSpeechTranscriber(),
        now: @escaping () -> Date = Date.init,
        startDelay: Duration = .milliseconds(250),
        retainedLevelCount: Int = 96
    ) {
        self.transcriber = transcriber
        self.now = now
        self.startDelay = startDelay
        self.retainedLevelCount = retainedLevelCount
        self.audioLevels = []
    }

    func handleFunctionKey(isPressed: Bool, appendTranscript: @escaping @MainActor (String) -> Void) {
        if isPressed {
            guard !isFunctionKeyDown else { return }
            isFunctionKeyDown = true
            operationTask = Task { [weak self] in
                await self?.beginRecording()
            }
        } else {
            guard isFunctionKeyDown else { return }
            isFunctionKeyDown = false
            operationTask = Task { [weak self] in
                await self?.finishRecording(appendTranscript: appendTranscript)
            }
        }
    }

    func beginRecording() async {
        guard state == .idle || isRecoverableMessageState else { return }
        state = .requestingPermission

        do {
            try await transcriber.requestAuthorization()
            guard isFunctionKeyDown else {
                state = .idle
                return
            }
            try await Task.sleep(for: startDelay)
            guard isFunctionKeyDown else {
                state = .idle
                return
            }

            transcriber.levelHandler = { [weak self] level in
                self?.recordAudioLevel(level)
            }
            if let cap = debugCapture, cap.isEnabled {
                transcriber.bufferHandler = { [weak cap] buffer, ts in
                    cap?.append(buffer: buffer, timestamp: ts)
                }
            } else {
                transcriber.bufferHandler = nil
            }
            try transcriber.start()
            if let cap = debugCapture, cap.isEnabled,
               let format = (transcriber as? AppleSpeechTranscriber)?.inputFormat {
                cap.startCapture(format: format)
            }
            recordingStartedAt = now()
            elapsedSeconds = 0
            state = .recording
            startTimer()
        } catch VoiceInputError.permissionDenied(let message) {
            isFunctionKeyDown = false
            state = .unavailable(message)
            resetCaptureMetrics()
        } catch {
            isFunctionKeyDown = false
            state = .failed(error.localizedDescription)
            resetCaptureMetrics()
        }
    }

    func finishRecording(appendTranscript: @escaping @MainActor (String) -> Void) async {
        guard state == .recording else { return }
        debugCapture?.stopCapture()
        stopTimer()
        state = .transcribing

        do {
            let transcript = try await transcriber.finish()
            let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTranscript.isEmpty {
                appendTranscript(trimmedTranscript)
            }
            state = .idle
            resetCaptureMetrics()
        } catch {
            transcriber.cancel()
            state = .failed(error.localizedDescription)
            resetCaptureMetrics()
        }
    }

    func cancel() {
        isFunctionKeyDown = false
        operationTask?.cancel()
        operationTask = nil
        debugCapture?.stopCapture()
        stopTimer()
        transcriber.cancel()
        state = .idle
        resetCaptureMetrics()
    }

    static func appendingTranscript(_ transcript: String, to draft: String) -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return draft }
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return trimmedTranscript
        }
        if draft.last?.isWhitespace == true {
            return draft + trimmedTranscript
        }
        return draft + " " + trimmedTranscript
    }

    private var isRecoverableMessageState: Bool {
        switch state {
        case .failed, .unavailable:
            true
        case .idle, .requestingPermission, .recording, .transcribing:
            false
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let recordingStartedAt else { return }
                elapsedSeconds = max(0, now().timeIntervalSince(recordingStartedAt))
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func resetCaptureMetrics() {
        recordingStartedAt = nil
        elapsedSeconds = 0
        audioLevel = 0
        ambientNoiseFloor = 0.03
        smoothedAudioLevel = 0
        audioLevels = []
    }

    private func recordAudioLevel(_ level: Double) {
        let displayLevel = voiceDisplayLevel(from: level)
        audioLevel = displayLevel
        audioLevels.append(displayLevel)
        if audioLevels.count > retainedLevelCount {
            audioLevels.removeFirst(audioLevels.count - retainedLevelCount)
        }
        debugCapture?.appendLevel(displayLevel, at: elapsedSeconds)
    }

    private func voiceDisplayLevel(from level: Double) -> Double {
        let s = settings
        let rawLevel = max(0, min(1, level))
        let speechThreshold = s?.speechThreshold ?? 0.18
        let floorBlend = rawLevel < ambientNoiseFloor + speechThreshold ? 0.06 : 0.015
        ambientNoiseFloor = max(0.01, min(0.65, ambientNoiseFloor * (1 - floorBlend) + rawLevel * floorBlend))

        let speechLevel = max(0, rawLevel - ambientNoiseFloor)
        let availableRange = max(speechThreshold, 1 - ambientNoiseFloor)
        let exponent = s?.expansionExponent ?? 0.58
        let gain = s?.gain ?? 1.25
        var expandedLevel = pow(min(1, speechLevel / availableRange), exponent) * gain

        let gate = s?.gateThreshold ?? 0.05
        if expandedLevel < gate { expandedLevel = 0 }

        let rise = s?.riseBlend ?? 0.65
        let decay = s?.fallDecay ?? 0.55
        smoothedAudioLevel = smoothedAudioLevel * (1 - rise) + min(1, expandedLevel) * rise
        if expandedLevel == 0 { smoothedAudioLevel *= decay }
        return max(0, min(1, smoothedAudioLevel))
    }
}

enum VoiceInputError: LocalizedError, Equatable {
    case permissionDenied(String)
    case speechUnavailable
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            message
        case .speechUnavailable:
            "Speech recognition is unavailable."
        case .recognitionFailed:
            "No transcript was produced."
        }
    }
}

@MainActor
final class AppleSpeechTranscriber: VoiceTranscribing {
    var levelHandler: (@MainActor @Sendable (Double) -> Void)?
    var bufferHandler: (@Sendable (AVAudioPCMBuffer, TimeInterval) -> Void)?

    var inputFormat: AVAudioFormat? { audioEngine.inputNode.outputFormat(forBus: 0) }

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var didReceiveRecognitionError = false
    private var hasInstalledTap = false

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestAuthorization() async throws {
        let speechStatus = await Self.requestSpeechAuthorizationStatus()
        guard speechStatus == .authorized else {
            throw VoiceInputError.permissionDenied("Speech recognition permission is required.")
        }

        let microphoneStatus = Self.microphoneAuthorizationStatus()
        switch microphoneStatus {
        case .authorized:
            return
        case .notDetermined:
            let isGranted = await Self.requestMicrophoneAccess()
            guard isGranted else {
                throw VoiceInputError.permissionDenied("Microphone permission is required.")
            }
        case .denied, .restricted:
            throw VoiceInputError.permissionDenied("Microphone permission is required.")
        @unknown default:
            throw VoiceInputError.permissionDenied("Microphone permission is required.")
        }
    }

    nonisolated private static func requestSpeechAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated private static func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    nonisolated private static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceInputError.speechUnavailable
        }

        latestTranscript = ""
        didReceiveRecognitionError = false
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        let levelReporter = VoiceLevelReporter(handler: levelHandler)
        let captureHandler = bufferHandler
        let tapStart = Date()
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat,
            block: Self.makeInputTapBlock(request: request, levelReporter: levelReporter,
                                          bufferHandler: captureHandler, startDate: tapStart)
        )
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()

        let resultSink = SpeechRecognitionResultSink { [weak self] transcript, didReceiveError in
            if let transcript {
                self?.latestTranscript = transcript
            }
            if didReceiveError {
                self?.didReceiveRecognitionError = true
            }
        }
        recognitionTask = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.makeRecognitionResultHandler(resultSink: resultSink)
        )
    }

    func finish() async throws -> String {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()

        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            cancel()
            throw error
        }

        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let didReceiveRecognitionError = didReceiveRecognitionError
        cleanup(cancelRecognitionTask: true)

        if !transcript.isEmpty {
            return transcript
        }
        if didReceiveRecognitionError {
            throw VoiceInputError.recognitionFailed
        }
        throw VoiceInputError.recognitionFailed
    }

    func cancel() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        cleanup(cancelRecognitionTask: true)
    }

    private func cleanup(cancelRecognitionTask: Bool) {
        if cancelRecognitionTask {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil
        latestTranscript = ""
        didReceiveRecognitionError = false
        levelHandler = nil
    }

    nonisolated private static func makeInputTapBlock(
        request: SFSpeechAudioBufferRecognitionRequest,
        levelReporter: VoiceLevelReporter,
        bufferHandler: (@Sendable (AVAudioPCMBuffer, TimeInterval) -> Void)?,
        startDate: Date
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            levelReporter.report(Self.normalizedLevel(from: buffer))
            bufferHandler?(buffer, Date().timeIntervalSince(startDate))
        }
    }

    nonisolated private static func makeRecognitionResultHandler(
        resultSink: SpeechRecognitionResultSink
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let transcript = result?.bestTranscription.formattedString
            resultSink.handle(transcript: transcript, didReceiveError: error != nil)
        }
    }

    nonisolated private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let channelCount = max(1, Int(buffer.format.channelCount))
        var sum: Float = 0
        var peak: Float = 0
        var sampleCount = 0
        for channelIndex in 0..<channelCount {
            let samples = channelData[channelIndex]
            for index in 0..<frameLength {
                let sample = samples[index]
                sum += sample * sample
                peak = max(peak, abs(sample))
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 0 }

        let rms = sqrt(sum / Float(sampleCount))
        let averagePower = 20 * log10(max(rms, 0.000_001))
        let peakPower = 20 * log10(max(peak, 0.000_001))
        let rmsLevel = max(0, min(1, (averagePower + 58) / 46))
        let peakLevel = max(0, min(1, (peakPower + 50) / 42))
        return Double(max(rmsLevel, peakLevel * 0.72))
    }
}

private final class VoiceLevelReporter: @unchecked Sendable {
    private let handler: (@MainActor @Sendable (Double) -> Void)?

    init(handler: (@MainActor @Sendable (Double) -> Void)?) {
        self.handler = handler
    }

    func report(_ level: Double) {
        guard let handler else { return }
        Task { @MainActor in
            handler(level)
        }
    }
}

private final class SpeechRecognitionResultSink: @unchecked Sendable {
    private let handler: @MainActor (String?, Bool) -> Void

    init(handler: @escaping @MainActor (String?, Bool) -> Void) {
        self.handler = handler
    }

    func handle(transcript: String?, didReceiveError: Bool) {
        Task { @MainActor in
            self.handler(transcript, didReceiveError)
        }
    }
}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
