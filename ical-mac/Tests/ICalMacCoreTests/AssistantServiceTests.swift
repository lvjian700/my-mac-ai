import Foundation
import Testing
@testable import ICalMacCore

@MainActor
struct AssistantServiceTests {
    @Test func toolLoopSendsToolResultThenReturnsFinalText() async throws {
        let calendarStore = FakeCalendarStore()
        calendarStore.calendars = [CalendarInfo(id: "cal-1", title: "Work", accountName: "iCloud", allowsContentModifications: true)]
        let client = FakeAnthropicClient(responses: [
            AnthropicMessageResponse(
                content: [.toolUse(id: "tool-1", name: "list_calendars", input: .object([:]))],
                stopReason: "tool_use"
            ),
            AnthropicMessageResponse(content: [.text("Work calendar is available.")], stopReason: "end_turn"),
        ])
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(skillDirectory: nil),
            toolExecutor: CalendarToolExecutor(calendarStore: calendarStore, memoryStore: MemoryStore(rootURL: root))
        )

        let text = try await service.send("what calendars do I have?", snapshot: nil)

        #expect(text == "Work calendar is available.")
        #expect(client.requests.count == 2)
        #expect(client.requests[1].messages.last?.content == [.toolResult(toolUseID: "tool-1", content: """
        [
          {
            "accountName" : "iCloud",
            "allowsContentModifications" : true,
            "id" : "cal-1",
            "title" : "Work"
          }
        ]
        """)])
    }

    @Test func missingAPIKeyThrowsBeforeNetwork() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeAnthropicClient(responses: [])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: nil),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(skillDirectory: nil),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root))
        )

        await #expect(throws: AnthropicError.missingAPIKey) {
            _ = try await service.send("hi", snapshot: nil)
        }
        #expect(client.requests.isEmpty)
    }

    @Test func reusedServicePreservesConversationHistoryAcrossTurns() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeAnthropicClient(responses: [
            AnthropicMessageResponse(content: [.text("First answer.")], stopReason: "end_turn"),
            AnthropicMessageResponse(content: [.text("Second answer.")], stopReason: "end_turn"),
        ])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(skillDirectory: nil),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root))
        )

        _ = try await service.send("first question", snapshot: nil)
        _ = try await service.send("second question", snapshot: nil)

        let secondRequestMessages = client.requests[1].messages
        #expect(secondRequestMessages.count == 3)
        #expect(secondRequestMessages[0].content == [.text("first question")])
        #expect(secondRequestMessages[1].content == [.text("First answer.")])
        #expect(secondRequestMessages[2].content == [.text("second question")])
    }

    @Test func repeatedToolUseStopsAtConfiguredLimit() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let client = FakeAnthropicClient(responses: [
            AnthropicMessageResponse(content: [.toolUse(id: "tool-1", name: "list_calendars", input: .object([:]))], stopReason: "tool_use"),
            AnthropicMessageResponse(content: [.toolUse(id: "tool-2", name: "list_calendars", input: .object([:]))], stopReason: "tool_use"),
        ])
        let service = AssistantService(
            client: client,
            apiKeyStore: FakeAPIKeyStore(key: "test-key"),
            memoryStore: MemoryStore(rootURL: root),
            promptStore: PromptStore(skillDirectory: nil),
            toolExecutor: CalendarToolExecutor(calendarStore: FakeCalendarStore(), memoryStore: MemoryStore(rootURL: root)),
            maxToolRounds: 1
        )

        await #expect(throws: AnthropicError.toolLoopLimitExceeded(1)) {
            _ = try await service.send("loop", snapshot: nil)
        }
    }
}
