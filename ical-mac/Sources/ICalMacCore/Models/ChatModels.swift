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

    public init(model: String = "claude-sonnet-4-6", userName: String? = nil) {
        self.model = model
        self.userName = userName
    }
}
