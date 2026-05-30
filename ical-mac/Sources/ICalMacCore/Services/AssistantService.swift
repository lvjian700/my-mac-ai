import Foundation

@MainActor
public final class AssistantService {
    private var inputHistory: [OpenAIInputItem] = []
    private let client: OpenAIClient
    private let apiKeyStore: APIKeyStore
    private let memoryStore: MemoryStore
    private let promptStore: PromptStore
    private let calendarAgent: CalendarAgent
    private let configuration: AssistantConfiguration
    private let maxToolRounds: Int

    public init(
        client: OpenAIClient,
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
        self.calendarAgent = CalendarAgent(
            client: client,
            toolExecutor: toolExecutor,
            configuration: configuration,
            maxToolRounds: maxToolRounds
        )
        self.configuration = configuration
        self.maxToolRounds = maxToolRounds
    }

    public func clearHistory() {
        inputHistory.removeAll()
    }

    public func send(_ text: String, snapshot: SessionSnapshot?) async throws -> String {
        guard let apiKey = apiKeyStore.readAPIKey(), !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let memory = memoryStore.readMemory()
        inputHistory.append(.message(role: "user", content: text))
        let instructions = promptStore.buildSystemPrompt(
            memory: memory,
            snapshot: snapshot,
            configuration: configuration
        )

        var toolRounds = 0
        while true {
            let request = OpenAIRequest(
                model: configuration.model,
                instructions: instructions,
                tools: [Self.calendarAgentTool],
                input: inputHistory
            )
            let response = try await client.createResponse(request, apiKey: apiKey)

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
                    let task = input.objectValue?["task"]?.stringValue ?? call.arguments
                    let result = try await calendarAgent.run(
                        task: task,
                        snapshot: snapshot,
                        memory: memory,
                        apiKey: apiKey
                    )
                    inputHistory.append(.functionCallOutput(callId: call.callId, output: result))
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

    // The single tool exposed to the ChatAgent — all calendar work is delegated through here.
    private static let calendarAgentTool = OpenAIToolDefinition(
        name: "calendar_agent",
        description: "Delegate a calendar task to the calendar specialist agent. The agent has full access to Apple Calendar tools (list, create, update events; write memory). Describe the task clearly — include dates, calendar names, event details, and any relevant context from the conversation.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("A clear description of the calendar work to perform."),
                ]),
            ]),
            "required": .array([.string("task")]),
        ])
    )

    private func parseArguments(_ arguments: String) -> JSONValue {
        let data = Data(arguments.utf8)
        return (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .object([:])
    }
}
