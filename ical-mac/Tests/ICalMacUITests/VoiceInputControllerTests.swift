import Foundation
import Testing
@testable import ICalMac

@MainActor
struct VoiceInputControllerTests {
    @Test func functionKeyPressStartsRecordingOnce() async {
        let transcriber = FakeVoiceTranscriber()
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)

        controller.handleFunctionKey(isPressed: true) { _ in }
        controller.handleFunctionKey(isPressed: true) { _ in }

        await waitForState(.recording, controller: controller)

        #expect(transcriber.requestAuthorizationCount == 1)
        #expect(transcriber.startCount == 1)
        #expect(controller.state == .recording)
        #expect((controller.audioLevels.last ?? 0) > 0.25)
    }

    @Test func functionKeyReleaseFinishesAndAppendsTranscript() async {
        let transcriber = FakeVoiceTranscriber(transcript: "Move lunch to noon")
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)
        var draft = "Tomorrow"

        controller.handleFunctionKey(isPressed: true) { _ in }
        await waitForState(.recording, controller: controller)
        controller.handleFunctionKey(isPressed: false) { transcript in
            draft = VoiceInputController.appendingTranscript(transcript, to: draft)
        }
        await waitForState(.idle, controller: controller)

        #expect(transcriber.finishCount == 1)
        #expect(draft == "Tomorrow Move lunch to noon")
        #expect(controller.state == .idle)
    }

    @Test func appendingTranscriptPreservesExistingDraftSpacing() {
        #expect(VoiceInputController.appendingTranscript("Schedule focus time", to: "") == "Schedule focus time")
        #expect(VoiceInputController.appendingTranscript("Schedule focus time", to: "Today ") == "Today Schedule focus time")
        #expect(VoiceInputController.appendingTranscript("  Schedule focus time  ", to: "Today") == "Today Schedule focus time")
        #expect(VoiceInputController.appendingTranscript("   ", to: "Today") == "Today")
    }

    @Test func permissionDenialLeavesDraftUnchangedAndShowsUnavailableState() async {
        let transcriber = FakeVoiceTranscriber(authorizationError: VoiceInputError.permissionDenied("Microphone permission is required."))
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)
        var draft = "Keep this draft"

        controller.handleFunctionKey(isPressed: true) { transcript in
            draft = VoiceInputController.appendingTranscript(transcript, to: draft)
        }
        await waitForState(.unavailable("Microphone permission is required."), controller: controller)

        #expect(draft == "Keep this draft")
        #expect(transcriber.startCount == 0)
        #expect(controller.state == .unavailable("Microphone permission is required."))
    }

    @Test func recognitionErrorLeavesDraftUnchangedAndShowsFailedState() async {
        let transcriber = FakeVoiceTranscriber(finishError: VoiceInputError.recognitionFailed)
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)
        var draft = "Keep this draft"

        controller.handleFunctionKey(isPressed: true) { _ in }
        await waitForState(.recording, controller: controller)
        controller.handleFunctionKey(isPressed: false) { transcript in
            draft = VoiceInputController.appendingTranscript(transcript, to: draft)
        }
        await waitForState(.failed("No transcript was produced."), controller: controller)

        #expect(draft == "Keep this draft")
        #expect(transcriber.finishCount == 1)
        #expect(transcriber.cancelCount == 1)
    }

    @Test func releaseDuringPermissionRequestDoesNotStartRecording() async {
        let transcriber = FakeVoiceTranscriber(authorizationDelay: .milliseconds(25))
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)

        controller.handleFunctionKey(isPressed: true) { _ in }
        await waitForState(.requestingPermission, controller: controller)
        controller.handleFunctionKey(isPressed: false) { _ in }
        await waitForState(.idle, controller: controller)

        #expect(transcriber.requestAuthorizationCount == 1)
        #expect(transcriber.startCount == 0)
        #expect(transcriber.finishCount == 0)
    }

    @Test func lowBackgroundLevelsAreSuppressedInMeter() async {
        let transcriber = FakeVoiceTranscriber(startLevels: [0.03, 0.04, 0.82])
        let controller = VoiceInputController(transcriber: transcriber, startDelay: .zero)

        controller.handleFunctionKey(isPressed: true) { _ in }
        await waitForState(.recording, controller: controller)

        let activeLevels = controller.audioLevels.suffix(3)
        #expect((activeLevels.first ?? 1) < 0.05)
        #expect((activeLevels.last ?? 0) > 0.25)
    }

    private func waitForState(_ expectedState: VoiceInputState, controller: VoiceInputController) async {
        for _ in 0..<50 {
            if controller.state == expectedState { return }
            await Task.yield()
        }
    }
}

@MainActor
private final class FakeVoiceTranscriber: VoiceTranscribing {
    var levelHandler: (@MainActor @Sendable (Double) -> Void)?
    var requestAuthorizationCount = 0
    var startCount = 0
    var finishCount = 0
    var cancelCount = 0

    private let transcript: String
    private let authorizationError: Error?
    private let finishError: Error?
    private let authorizationDelay: Duration?
    private let startLevels: [Double]

    init(
        transcript: String = "",
        authorizationError: Error? = nil,
        finishError: Error? = nil,
        authorizationDelay: Duration? = nil,
        startLevels: [Double] = [0.6]
    ) {
        self.transcript = transcript
        self.authorizationError = authorizationError
        self.finishError = finishError
        self.authorizationDelay = authorizationDelay
        self.startLevels = startLevels
    }

    func requestAuthorization() async throws {
        requestAuthorizationCount += 1
        if let authorizationDelay {
            try await Task.sleep(for: authorizationDelay)
        }
        if let authorizationError {
            throw authorizationError
        }
    }

    func start() throws {
        startCount += 1
        for level in startLevels {
            levelHandler?(level)
        }
    }

    func finish() async throws -> String {
        finishCount += 1
        if let finishError {
            throw finishError
        }
        return transcript
    }

    func cancel() {
        cancelCount += 1
    }
}
