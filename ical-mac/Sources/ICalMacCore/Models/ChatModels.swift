import Foundation

public enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var role: ChatRole
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), role: ChatRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

public struct ConversationSummary: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var lastMessagePreview: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String,
        lastMessagePreview: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ChatConversationRecord: Identifiable, Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [ChatMessage]
    public var transcript: [OpenAIInputItem]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: UUID = UUID(),
        title: String = "New conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        transcript: [OpenAIInputItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.transcript = transcript
    }

    public var summary: ConversationSummary {
        ConversationSummary(
            id: id,
            title: title,
            lastMessagePreview: Self.preview(from: messages),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public mutating func refreshMetadata(now: Date = Date()) {
        updatedAt = now
        title = Self.title(from: messages)
    }

    public static func title(from messages: [ChatMessage]) -> String {
        let source = messages.first(where: { $0.role == .user })?.text ?? "New conversation"
        return normalizedPreview(source, limit: 48)
    }

    public static func preview(from messages: [ChatMessage]) -> String {
        guard let text = messages.last(where: { $0.role == .user || $0.role == .assistant })?.text else {
            return "No messages yet"
        }
        return normalizedPreview(text, limit: 72)
    }

    private static func normalizedPreview(_ text: String, limit: Int) -> String {
        let normalized = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard normalized.count > limit else { return normalized.isEmpty ? "New conversation" : normalized }
        let index = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

public struct ToolCall: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var input: JSONValue

    public init(id: String, name: String, input: JSONValue) {
        self.id = id
        self.name = name
        self.input = input
    }
}

public struct AssistantConfiguration: Codable, Equatable, Sendable {
    public var model: String
    public var userName: String?

    public init(model: String = "gpt-4.5-mini", userName: String? = nil) {
        self.model = model
        self.userName = userName
    }
}
