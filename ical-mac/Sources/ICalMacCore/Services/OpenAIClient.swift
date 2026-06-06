import Foundation

public enum OpenAIError: LocalizedError, Equatable, Sendable {
    case missingAPIKey
    case badHTTPStatus(Int, String)
    case emptyResponse
    case toolLoopLimitExceeded(Int)
    /// Retryable HTTP error (429/502/503) that persisted after all retry attempts.
    /// `body` contains the raw server response for debugging.
    case transientFailureExhausted(code: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing."
        case .badHTTPStatus(let status, let body):
            return "OpenAI request failed with HTTP \(status): \(body)"
        case .emptyResponse:
            return "OpenAI returned no assistant text."
        case .toolLoopLimitExceeded(let limit):
            return "Assistant stopped after \(limit) tool rounds without a final answer."
        case .transientFailureExhausted(let code, _):
            return "OpenAI is temporarily unavailable (HTTP \(code)). Please try again in a moment."
        }
    }
}

public protocol OpenAIClient: Sendable {
    func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse
    func streamResponse(_ request: OpenAIRequest, apiKey: String) async throws -> AsyncThrowingStream<OpenAIStreamEvent, Error>
}

public struct URLSessionOpenAIClient: OpenAIClient {
    private let endpoint: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.badHTTPStatus(-1, "Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.badHTTPStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode(OpenAIResponse.self, from: data)
    }

    public func streamResponse(_ request: OpenAIRequest, apiKey: String) async throws -> AsyncThrowingStream<OpenAIStreamEvent, Error> {
        var streamingRequest = request
        streamingRequest.stream = true

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        urlRequest.httpBody = try encoder.encode(streamingRequest)

        let (asyncBytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.badHTTPStatus(-1, "Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            var body = ""
            for try await line in asyncBytes.lines { body += line }
            throw OpenAIError.badHTTPStatus(http.statusCode, body)
        }

        let decoder = self.decoder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let dataStr = String(line.dropFirst("data: ".count))
                        guard !dataStr.isEmpty, dataStr != "[DONE]" else { continue }
                        guard let data = dataStr.data(using: .utf8) else { continue }
                        if let event = Self.parseSSEEvent(data: data, decoder: decoder) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseSSEEvent(data: Data, decoder: JSONDecoder) -> OpenAIStreamEvent? {
        guard let sniff = try? decoder.decode(SSESniff.self, from: data) else { return nil }
        switch sniff.type {
        case "response.output_text.delta":
            guard let payload = try? decoder.decode(SSETextDelta.self, from: data) else { return nil }
            return .textDelta(payload.delta)
        case "response.completed":
            guard let payload = try? decoder.decode(SSECompleted.self, from: data) else { return nil }
            return .completed(payload.response)
        default:
            return nil
        }
    }
}

// ── Request ───────────────────────────────────────────────────────────────

public struct OpenAIRequest: Codable, Sendable {
    public var model: String
    public var instructions: String
    public var maxOutputTokens: Int
    public var tools: [OpenAIToolDefinition]
    public var input: [OpenAIInputItem]
    public var stream: Bool

    public init(
        model: String,
        instructions: String,
        maxOutputTokens: Int = 4096,
        tools: [OpenAIToolDefinition],
        input: [OpenAIInputItem],
        stream: Bool = false
    ) {
        self.model = model
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens
        self.tools = tools
        self.input = input
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case tools
        case input
        case stream
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(maxOutputTokens, forKey: .maxOutputTokens)
        try container.encode(tools, forKey: .tools)
        try container.encode(input, forKey: .input)
        if stream { try container.encode(true, forKey: .stream) }
    }
}

public struct OpenAIToolDefinition: Codable, Equatable, Sendable {
    public var type: String
    public var name: String
    public var description: String
    public var parameters: JSONValue

    public init(name: String, description: String, parameters: JSONValue) {
        self.type = "function"
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// Union type for items in the input[] array.
// Discriminated by presence of "type" field (function items) vs "role" field (message items).
public enum OpenAIInputItem: Codable, Equatable, Sendable {
    case message(role: String, content: String)
    case functionCall(callId: String, name: String, arguments: String)
    case functionCallOutput(callId: String, output: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case role, content
        case callId = "call_id"
        case name, arguments, output
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try? container.decode(String.self, forKey: .type)
        switch type {
        case "function_call":
            self = .functionCall(
                callId: try container.decode(String.self, forKey: .callId),
                name: try container.decode(String.self, forKey: .name),
                arguments: try container.decode(String.self, forKey: .arguments)
            )
        case "function_call_output":
            self = .functionCallOutput(
                callId: try container.decode(String.self, forKey: .callId),
                output: try container.decode(String.self, forKey: .output)
            )
        default:
            self = .message(
                role: try container.decode(String.self, forKey: .role),
                content: try container.decode(String.self, forKey: .content)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .message(let role, let content):
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        case .functionCall(let callId, let name, let arguments):
            try container.encode("function_call", forKey: .type)
            try container.encode(callId, forKey: .callId)
            try container.encode(name, forKey: .name)
            try container.encode(arguments, forKey: .arguments)
        case .functionCallOutput(let callId, let output):
            try container.encode("function_call_output", forKey: .type)
            try container.encode(callId, forKey: .callId)
            try container.encode(output, forKey: .output)
        }
    }
}

// ── Response ──────────────────────────────────────────────────────────────

public struct OpenAIResponse: Codable, Sendable {
    public var output: [OpenAIOutputItem]

    public init(output: [OpenAIOutputItem]) {
        self.output = output
    }
}

public enum OpenAIOutputItem: Codable, Sendable {
    case message(role: String, content: [OpenAIOutputContent])
    case functionCall(callId: String, name: String, arguments: String)
    case other

    private enum CodingKeys: String, CodingKey {
        case type
        case role, content
        case callId = "call_id"
        case name, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""
        switch type {
        case "message":
            self = .message(
                role: (try? container.decode(String.self, forKey: .role)) ?? "assistant",
                content: (try? container.decode([OpenAIOutputContent].self, forKey: .content)) ?? []
            )
        case "function_call":
            self = .functionCall(
                callId: try container.decode(String.self, forKey: .callId),
                name: try container.decode(String.self, forKey: .name),
                arguments: try container.decode(String.self, forKey: .arguments)
            )
        default:
            self = .other
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .message(let role, let content):
            try container.encode("message", forKey: .type)
            try container.encode(role, forKey: .role)
            try container.encode(content, forKey: .content)
        case .functionCall(let callId, let name, let arguments):
            try container.encode("function_call", forKey: .type)
            try container.encode(callId, forKey: .callId)
            try container.encode(name, forKey: .name)
            try container.encode(arguments, forKey: .arguments)
        case .other:
            break
        }
    }
}

public struct OpenAIOutputContent: Codable, Sendable {
    public var type: String
    public var text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

// ── Streaming ─────────────────────────────────────────────────────────────

public enum OpenAIStreamEvent: Sendable {
    case textDelta(String)
    case completed(OpenAIResponse)
}

private struct SSESniff: Decodable { let type: String }
private struct SSETextDelta: Decodable { let delta: String }
private struct SSECompleted: Decodable { let response: OpenAIResponse }

// ── Convenience extensions ────────────────────────────────────────────────

public extension Array where Element == OpenAIOutputItem {
    var functionCalls: [(callId: String, name: String, arguments: String)] {
        compactMap { item in
            if case .functionCall(let callId, let name, let arguments) = item {
                return (callId, name, arguments)
            }
            return nil
        }
    }

    var text: String {
        compactMap { item -> String? in
            guard case .message(_, let content) = item else { return nil }
            return content.compactMap { c in c.type == "output_text" ? c.text : nil }.joined()
        }.joined()
    }
}
