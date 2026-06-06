import Foundation

public enum ConversationStoreError: LocalizedError, Equatable, Sendable {
    case cannotCreateDirectory(String)
    case conversationNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory(let path):
            return "Cannot create conversation directory at \(path)."
        case .conversationNotFound(let id):
            return "Conversation \(id.uuidString) was not found."
        }
    }
}

public protocol ConversationStore: Sendable {
    func listSummaries() async throws -> [ConversationSummary]
    func loadConversation(id: UUID) async throws -> ChatConversationRecord
    func createConversation(messages: [ChatMessage], transcript: [OpenAIInputItem]) async throws -> ChatConversationRecord
    func saveConversation(_ conversation: ChatConversationRecord) async throws
    func deleteConversation(id: UUID) async throws
}

public actor JSONConversationStore: ConversationStore {
    private let directoryURL: URL
    private let indexURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".my-mac-ai/ical", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        self.indexURL = directoryURL.appendingPathComponent("index.json")
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601String(from: date))
        }
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.date(fromISO8601String: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date.")
        }
        self.decoder = decoder
    }

    public func listSummaries() async throws -> [ConversationSummary] {
        let summaries = try validRecords()
            .map(\.summary)
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        try writeIndex(summaries)
        return summaries
    }

    public func loadConversation(id: UUID) async throws -> ChatConversationRecord {
        let url = recordURL(id: id)
        guard let data = try? Data(contentsOf: url) else {
            throw ConversationStoreError.conversationNotFound(id)
        }
        do {
            return try decoder.decode(ChatConversationRecord.self, from: data)
        } catch {
            throw ConversationStoreError.conversationNotFound(id)
        }
    }

    public func createConversation(
        messages: [ChatMessage] = [],
        transcript: [OpenAIInputItem] = []
    ) async throws -> ChatConversationRecord {
        var conversation = ChatConversationRecord(messages: messages, transcript: transcript)
        conversation.refreshMetadata()
        try await saveConversation(conversation)
        return conversation
    }

    public func saveConversation(_ conversation: ChatConversationRecord) async throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(conversation)
        try data.write(to: recordURL(id: conversation.id), options: .atomic)
        _ = try await listSummaries()
    }

    public func deleteConversation(id: UUID) async throws {
        let url = recordURL(id: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        _ = try await listSummaries()
    }

    private func validRecords() throws -> [ChatConversationRecord] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            try ensureDirectoryExists()
            try writeIndex([])
            return []
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap { url in
            guard url.pathExtension == "json", url.lastPathComponent != "index.json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(ChatConversationRecord.self, from: data)
        }
    }

    private func writeIndex(_ summaries: [ConversationSummary]) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(summaries)
        try data.write(to: indexURL, options: .atomic)
    }

    private func recordURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectoryExists() throws {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw ConversationStoreError.cannotCreateDirectory(directoryURL.path)
        }
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func date(fromISO8601String value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let wholeSecondFormatter = ISO8601DateFormatter()
        wholeSecondFormatter.formatOptions = [.withInternetDateTime]
        return wholeSecondFormatter.date(from: value)
    }
}
