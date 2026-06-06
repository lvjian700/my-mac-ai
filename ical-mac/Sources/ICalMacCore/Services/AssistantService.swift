import Foundation
import os.log

@MainActor
public final class AssistantService {
    private var inputHistory: [OpenAIInputItem] = []
    private let client: OpenAIClient
    private let apiKeyStore: APIKeyStore
    private let memoryStore: MemoryStore
    private let promptStore: PromptStore
    private let toolExecutor: CalendarToolExecutor
    private let configuration: AssistantConfiguration
    private let maxToolRounds: Int

    public init(
        client: OpenAIClient,
        apiKeyStore: APIKeyStore,
        memoryStore: MemoryStore,
        promptStore: PromptStore,
        toolExecutor: CalendarToolExecutor,
        configuration: AssistantConfiguration = AssistantConfiguration(),
        maxToolRounds: Int = 8,
        inputHistory: [OpenAIInputItem] = []
    ) {
        self.inputHistory = inputHistory
        self.client = client
        self.apiKeyStore = apiKeyStore
        self.memoryStore = memoryStore
        self.promptStore = promptStore
        self.toolExecutor = toolExecutor
        self.configuration = configuration
        self.maxToolRounds = maxToolRounds
    }

    public var transcript: [OpenAIInputItem] {
        inputHistory
    }

    public func clearHistory() {
        inputHistory.removeAll()
    }

    public func replaceHistory(with inputHistory: [OpenAIInputItem]) {
        self.inputHistory = inputHistory
    }

    public func send(_ text: String, snapshot: SessionSnapshot?) async throws -> String {
        guard let apiKey = apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        inputHistory.append(.message(role: "user", content: text))
        let instructions = promptStore.buildSystemPrompt(
            memory: memoryStore.readMemory(),
            snapshot: snapshot,
            configuration: configuration
        )

        var toolRounds = 0
        while true {
            let request = OpenAIRequest(
                model: configuration.model,
                instructions: instructions,
                tools: CalendarToolExecutor.toolDefinitions,
                input: inputHistory
            )
            let response = try await withRetry { try await client.createResponse(request, apiKey: apiKey) }

            let toolCalls = response.output.functionCalls
            if !toolCalls.isEmpty {
                guard toolRounds < maxToolRounds else {
                    throw OpenAIError.toolLoopLimitExceeded(maxToolRounds)
                }
                toolRounds += 1
                for call in toolCalls {
                    inputHistory.append(.functionCall(callId: call.callId, name: call.name, arguments: call.arguments))
                }
                for call in toolCalls {
                    let input = parseArguments(call.arguments)
                    let output = await toolExecutor.execute(name: call.name, input: input)
                    inputHistory.append(.functionCallOutput(callId: call.callId, output: output))
                }
                continue
            }

            let output = response.output.text
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OpenAIError.emptyResponse
            }
            inputHistory.append(.message(role: "assistant", content: output))
            return output
        }
    }

    public func send(
        _ text: String,
        snapshot: SessionSnapshot?,
        onToken: @escaping (String) -> Void,
        onToolCall: @escaping (String) -> Void = { _ in },
        onRetry: @escaping (Int, Int) -> Void = { _, _ in }
    ) async throws -> String {
        guard let apiKey = apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        inputHistory.append(.message(role: "user", content: text))
        let instructions = promptStore.buildSystemPrompt(
            memory: memoryStore.readMemory(),
            snapshot: snapshot,
            configuration: configuration
        )

        var toolRounds = 0
        while true {
            let request = OpenAIRequest(
                model: configuration.model,
                instructions: instructions,
                tools: CalendarToolExecutor.toolDefinitions,
                input: inputHistory
            )

            var completedResponse: OpenAIResponse?
            let stream = try await withRetry(onRetry: onRetry) { try await client.streamResponse(request, apiKey: apiKey) }
            for try await event in stream {
                switch event {
                case .textDelta(let delta) where !delta.isEmpty:
                    onToken(delta)
                case .completed(let response):
                    completedResponse = response
                default:
                    break
                }
            }
            guard let response = completedResponse else {
                throw OpenAIError.emptyResponse
            }

            let toolCalls = response.output.functionCalls
            if !toolCalls.isEmpty {
                guard toolRounds < maxToolRounds else {
                    throw OpenAIError.toolLoopLimitExceeded(maxToolRounds)
                }
                toolRounds += 1
                for call in toolCalls {
                    inputHistory.append(.functionCall(callId: call.callId, name: call.name, arguments: call.arguments))
                }
                for call in toolCalls {
                    onToolCall(call.name)
                    let input = parseArguments(call.arguments)
                    let output = await toolExecutor.execute(name: call.name, input: input)
                    inputHistory.append(.functionCallOutput(callId: call.callId, output: output))
                }
                continue
            }

            let output = response.output.text
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OpenAIError.emptyResponse
            }
            inputHistory.append(.message(role: "assistant", content: output))
            return output
        }
    }

    public func evaluateInvitations(
        _ invitations: [CalendarEvent],
        snapshot: SessionSnapshot?
    ) async throws -> String {
        guard let apiKey = apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        let systemPrompt = promptStore.buildSystemPrompt(
            memory: memoryStore.readMemory(),
            snapshot: snapshot,
            configuration: configuration
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        let lines = invitations.map { inv -> String in
            let from = inv.invitation?.organizerName ?? inv.invitation?.organizerURL ?? "unknown"
            let status = inv.invitation?.responseStatus.rawValue ?? "pending"
            return "- \"\(inv.title)\" from \(from) — \(dateFormatter.string(from: inv.startDate)) [\(status)]"
        }.joined(separator: "\n")
        let userMessage = """
            New calendar invitations detected. Based on your memory and preferences, \
            evaluate each one briefly. If you have a relevant rule, recommend accept / decline / tentative \
            and explain why. If not, just summarize: how many and from whom.

            Invitations:
            \(lines)
            """
        let request = OpenAIRequest(
            model: configuration.model,
            instructions: systemPrompt,
            tools: [],
            input: [.message(role: "user", content: userMessage)]
        )
        let response = try await client.createResponse(request, apiKey: apiKey)
        return response.output.text
    }

    private static let logger = Logger(subsystem: "jian.ai.ical-mac", category: "AssistantService")

    // Retries on transient OpenAI HTTP errors (429, 502, 503) with 1s/2s/3s backoff.
    // onRetry is called with (attemptNumber, maxRetries) before each sleep.
    // On exhaustion logs the full server body at .error level and throws transientFailureExhausted.
    private func withRetry<T>(
        onRetry: ((Int, Int) -> Void)? = nil,
        _ operation: () async throws -> T
    ) async throws -> T {
        let maxRetries = 3
        let retryDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(3)]
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch let error as OpenAIError {
                guard case .badHTTPStatus(let code, let body) = error,
                      [429, 502, 503].contains(code) else {
                    throw error
                }
                guard attempt < maxRetries else {
                    Self.logger.error("OpenAI transient failure exhausted after \(maxRetries) retries — HTTP \(code): \(body)")
                    throw OpenAIError.transientFailureExhausted(code: code, body: body)
                }
                attempt += 1
                onRetry?(attempt, maxRetries)
                try await Task.sleep(for: retryDelays[attempt - 1])
            }
        }
    }

    private func parseArguments(_ arguments: String) -> JSONValue {
        let data = Data(arguments.utf8)
        return (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .object([:])
    }
}
