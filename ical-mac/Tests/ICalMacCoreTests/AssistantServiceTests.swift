import Foundation
import Testing
@testable import ICalMac

@MainActor
struct AssistantServiceTests {
    @Test func toolLoopSendsToolResultThenReturnsFinalText() async throws {
        let calendarStore = FakeCalendarStore()
        calendarStore.calendars = [CalendarInfo(id: "cal-1", title: "Work", accountName: "iCloud", allowsContentModifications: true)]
        let client = FakeOpenAIClient(responses: [
            OpenAIResponse(output: [
                .functionCall(callId: "fc-1", name: "list_calendars", arguments: "{}")
            ]),
            OpenAIResponse(output: [
                .message(role: "assistant", content: [.init(type: "output_text", text: "Work calendar is available.")])
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
        #expect(client.requests.count == 2)
        let secondInput = client.requests[1].input
        #expect(secondInput.contains(.functionCall(callId: "fc-1", name: "list_calendars", arguments: "{}")))
        #expect(secondInput.contains(where: { item in
            if case .functionCallOutput(let callId, _) = item { return callId == "fc-1" }
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

    @Test func seededHistoryIsReusedOnNextTurn() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeOpenAIClient(responses: [
            OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Resumed answer.")])]),
        ])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root)),
            inputHistory: [
                .message(role: "user", content: "first question"),
                .message(role: "assistant", content: "First answer.")
            ]
        )

        _ = try await service.send("second question", snapshot: nil)

        #expect(client.requests[0].input == [
            .message(role: "user", content: "first question"),
            .message(role: "assistant", content: "First answer."),
            .message(role: "user", content: "second question")
        ])
        #expect(service.transcript.last == .message(role: "assistant", content: "Resumed answer."))
    }

    @Test func repeatedToolUseStopsAtConfiguredLimit() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeOpenAIClient(responses: [
            OpenAIResponse(output: [.functionCall(callId: "fc-1", name: "list_calendars", arguments: "{}")]),
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
