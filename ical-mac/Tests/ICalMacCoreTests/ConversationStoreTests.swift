import Foundation
import Testing
@testable import ICalMac

struct ConversationStoreTests {
    @Test func jsonStoreCreatesListsLoadsAndDeletesConversations() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = JSONConversationStore(rootURL: root)
        let first = try await store.createConversation(
            messages: [ChatMessage(role: .assistant, text: "Welcome")]
        )
        try await Task.sleep(for: .milliseconds(10))
        let second = try await store.createConversation(
            messages: [
                ChatMessage(role: .assistant, text: "Welcome"),
                ChatMessage(role: .user, text: "Please move standup tomorrow morning")
            ],
            transcript: [.message(role: "user", content: "Please move standup tomorrow morning")]
        )

        let summaries = try await store.listSummaries()

        #expect(summaries.map(\.id) == [second.id, first.id])
        #expect(summaries[0].title == "Please move standup tomorrow morning")
        #expect(summaries[0].lastMessagePreview == "Please move standup tomorrow morning")

        let loaded = try await store.loadConversation(id: second.id)
        #expect(loaded.transcript == [.message(role: "user", content: "Please move standup tomorrow morning")])

        try await store.deleteConversation(id: second.id)
        #expect(try await store.listSummaries().map(\.id) == [first.id])
    }

    @Test func jsonStoreSkipsCorruptRecordsWhenListing() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = JSONConversationStore(rootURL: root)
        let valid = try await store.createConversation(messages: [ChatMessage(role: .user, text: "Valid chat")])
        let directory = root.appendingPathComponent("conversations", isDirectory: true)
        try "not-json".write(
            to: directory.appendingPathComponent("\(UUID().uuidString).json"),
            atomically: true,
            encoding: .utf8
        )

        let summaries = try await store.listSummaries()

        #expect(summaries.map(\.id) == [valid.id])
    }
}
