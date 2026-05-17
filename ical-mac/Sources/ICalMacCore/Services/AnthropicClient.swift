import Foundation

public enum AnthropicError: LocalizedError, Equatable {
    case missingAPIKey
    case badHTTPStatus(Int, String)
    case emptyResponse
    case toolLoopLimitExceeded(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is missing."
        case .badHTTPStatus(let status, let body):
            return "Anthropic request failed with HTTP \(status): \(body)"
        case .emptyResponse:
            return "Anthropic returned no assistant text."
        case .toolLoopLimitExceeded(let limit):
            return "Assistant stopped after \(limit) tool rounds without a final answer."
        }
    }
}

public protocol AnthropicClient: Sendable {
    func createMessage(_ request: AnthropicMessageRequest, apiKey: String) async throws -> AnthropicMessageResponse
}

public struct URLSessionAnthropicClient: AnthropicClient {
    private let endpoint: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func createMessage(_ request: AnthropicMessageRequest, apiKey: String) async throws -> AnthropicMessageResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.badHTTPStatus(-1, "Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AnthropicError.badHTTPStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode(AnthropicMessageResponse.self, from: data)
    }
}

public struct AnthropicMessageRequest: Codable, Equatable, Sendable {
    public var model: String
    public var maxTokens: Int
    public var system: String
    public var tools: [AnthropicToolDefinition]
    public var messages: [AnthropicMessageParam]

    public init(
        model: String,
        maxTokens: Int = 4096,
        system: String,
        tools: [AnthropicToolDefinition],
        messages: [AnthropicMessageParam]
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.tools = tools
        self.messages = messages
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case tools
        case messages
    }
}

public struct AnthropicMessageParam: Codable, Equatable, Sendable {
    public var role: String
    public var content: [AnthropicContentBlock]

    public init(role: String, content: [AnthropicContentBlock]) {
        self.role = role
        self.content = content
    }
}

public enum AnthropicContentBlock: Codable, Equatable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, content: String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case toolUseID = "tool_use_id"
        case content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                input: try container.decode(JSONValue.self, forKey: .input)
            )
        case "tool_result":
            self = .toolResult(
                toolUseID: try container.decode(String.self, forKey: .toolUseID),
                content: try container.decode(String.self, forKey: .content)
            )
        default:
            self = .text("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            try container.encode(content, forKey: .content)
        }
    }
}

public struct AnthropicMessageResponse: Codable, Equatable, Sendable {
    public var id: String?
    public var role: String?
    public var content: [AnthropicContentBlock]
    public var stopReason: String?

    public init(
        id: String? = nil,
        role: String? = nil,
        content: [AnthropicContentBlock],
        stopReason: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.stopReason = stopReason
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case stopReason = "stop_reason"
    }
}

public struct AnthropicToolDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var description: String
    public var inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}
