import Foundation
import Testing
@testable import ICalMacCore

@MainActor
struct AssistantServiceTests {
    // ChatAgent delegates to CalendarAgent via calendar_agent tool.
    // Sequence: ChatAgent call → calendar_agent tool call → CalendarAgent call → list_calendars tool call
    //           → CalendarAgent final → ChatAgent final synthesis (4 API calls total).
    @Test func toolLoopDelegatesToCalendarAgentThenReturnsFinalText() async throws {
        let calendarStore = FakeCalendarStore()
        calendarStore.calendars = [CalendarInfo(id: "cal-1", title: "Work", accountName: "iCloud", allowsContentModifications: true)]
        let client = FakeOpenAIClient(responses: [
            // ChatAgent round 1: delegates to calendar_agent
            OpenAIResponse(output: [
                .functionCall(callId: "ca-1", name: "calendar_agent", arguments: #"{"task":"list calendars"}"#),
            ]),
            // CalendarAgent round 1: calls list_calendars
            OpenAIResponse(output: [
                .functionCall(callId: "fc-1", name: "list_calendars", arguments: "{}"),
            ]),
            // CalendarAgent final: returns result text
            OpenAIResponse(output: [
                .message(role: "assistant", content: [.init(type: "output_text", text: "Work calendar is available.")]),
            ]),
            // ChatAgent round 2: synthesises and returns to user
            OpenAIResponse(output: [
                .message(role: "assistant", content: [.init(type: "output_text", text: "Work calendar is available.")]),
            ]),
        ])
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(),
            toolExecutor: CalendarToolExecutor(calendarStore: calendarStore, memoryStore: MemoryStore(rootURL: root))
        )

        let text = try await service.send("what calendars do I have?", snapshot: nil)

        #expect(text == "Work calendar is available.")
        #expect(client.requests.count == 4)
        // ChatAgent's second request must include the calendar_agent call and its output
        let chatAgentSecondInput = client.requests[3].input
        #expect(chatAgentSecondInput.contains(.functionCall(callId: "ca-1", name: "calendar_agent", arguments: #"{"task":"list calendars"}"#)))
        #expect(chatAgentSecondInput.contains(where: { item in
            if case .functionCallOutput(let callId, _) = item { return callId == "ca-1" }
            return false
        }))
    }

    @Test func missingAPIKeyThrowsBeforeNetwork() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeOpenAIClient(responses: [])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: nil),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root))
        )

        await #expect(throws: OpenAIError.missingAPIKey) {
            _ = try await service.send("hi", snapshot: nil)
        }
        #expect(client.requests.isEmpty)
    }

    @Test func reusedServicePreservesConversationHistoryAcrossTurns() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeOpenAIClient(responses: [
            OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "First answer.")])]),
            OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Second answer.")])]),
        ])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root))
        )

        _ = try await service.send("first question", snapshot: nil)
        _ = try await service.send("second question", snapshot: nil)

        let secondInput = client.requests[1].input
        #expect(secondInput.count == 3)
        #expect(secondInput[0] == .message(role: "user", content: "first question"))
        #expect(secondInput[1] == .message(role: "assistant", content: "First answer."))
        #expect(secondInput[2] == .message(role: "user", content: "second question"))
    }

    // maxToolRounds limits CalendarAgent's inner tool loop.
    // With limit=1, CalendarAgent throws after its first tool round returns another tool call.
    @Test func repeatedToolUseStopsAtConfiguredLimit() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeOpenAIClient(responses: [
            // ChatAgent: delegates to calendar_agent
            OpenAIResponse(output: [.functionCall(callId: "ca-1", name: "calendar_agent", arguments: #"{"task":"loop"}"#)]),
            // CalendarAgent round 1: returns another tool call
            OpenAIResponse(output: [.functionCall(callId: "fc-1", name: "list_calendars", arguments: "{}")]),
            // CalendarAgent round 2: would exceed limit
            OpenAIResponse(output: [.functionCall(callId: "fc-2", name: "list_calendars", arguments: "{}")]),
        ])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root)),
            maxToolRounds: 1
        )

        await #expect(throws: OpenAIError.toolLoopLimitExceeded(1)) {
            _ = try await service.send("loop", snapshot: nil)
        }
    }
}
