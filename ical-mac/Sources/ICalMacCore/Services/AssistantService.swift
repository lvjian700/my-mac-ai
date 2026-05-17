import Foundation

@MainActor
public final class AssistantService {
    private var messages: [AnthropicMessageParam] = []
    private let client: AnthropicClient
    private let apiKeyStore: APIKeyStore
    private let memoryStore: MemoryStore
    private let promptStore: PromptStore
    private let toolExecutor: CalendarToolExecutor
    private let configuration: AssistantConfiguration
    private let maxToolRounds: Int

    public init(
        client: AnthropicClient,
        apiKeyStore: APIKeyStore,
        memoryStore: MemoryStore,
        promptStore: PromptStore,
        toolExecutor: CalendarToolExecutor,
        configuration: AssistantConfiguration = AssistantConfiguration(),
        maxToolRounds: Int = 8
    ) {
        self.client = client
        self.apiKeyStore = apiKeyStore
        self.memoryStore = memoryStore
        self.promptStore = promptStore
        self.toolExecutor = toolExecutor
        self.configuration = configuration
        self.maxToolRounds = maxToolRounds
    }

    public func clearHistory() {
        messages.removeAll()
    }

    public func send(_ text: String, snapshot: SessionSnapshot?) async throws -> String {
        guard let apiKey = apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        messages.append(.init(role: "user", content: [.text(text)]))
        let system = promptStore.buildSystemPrompt(
            memory: memoryStore.readMemory(),
            snapshot: snapshot,
            configuration: configuration
        )

        var toolRounds = 0
        while true {
            let request = AnthropicMessageRequest(
                model: configuration.model,
                system: system,
                tools: CalendarToolExecutor.toolDefinitions,
                messages: messages
            )
            let response = try await client.createMessage(request, apiKey: apiKey)
            messages.append(.init(role: "assistant", content: response.content))

            let toolUses = response.content.toolUses
            if response.stopReason == "tool_use" || !toolUses.isEmpty {
                guard toolRounds < maxToolRounds else {
                    throw AnthropicError.toolLoopLimitExceeded(maxToolRounds)
                }
                toolRounds += 1
                var toolResults: [AnthropicContentBlock] = []
                for toolUse in toolUses {
                    let output = await toolExecutor.execute(name: toolUse.name, input: toolUse.input)
                    toolResults.append(.toolResult(toolUseID: toolUse.id, content: output))
                }
                messages.append(.init(role: "user", content: toolResults))
                continue
            }

            let output = response.content.text
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AnthropicError.emptyResponse
            }
            return output
        }
    }
}

private extension Array where Element == AnthropicContentBlock {
    var text: String {
        compactMap { block in
            if case .text(let text) = block { return text }
            return nil
        }
        .joined()
    }

    var toolUses: [(id: String, name: String, input: JSONValue)] {
        compactMap { block in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }
    }
}
