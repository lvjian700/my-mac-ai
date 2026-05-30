import Foundation

@MainActor
final class CalendarAgent {
    private let client: OpenAIClient
    private let toolExecutor: CalendarToolExecutor
    private let configuration: AssistantConfiguration
    private let maxToolRounds: Int

    init(
        client: OpenAIClient,
        toolExecutor: CalendarToolExecutor,
        configuration: AssistantConfiguration,
        maxToolRounds: Int = 8
    ) {
        self.client = client
        self.toolExecutor = toolExecutor
        self.configuration = configuration
        self.maxToolRounds = maxToolRounds
    }

    func run(
        task: String,
        snapshot: SessionSnapshot?,
        memory: String,
        apiKey: String
    ) async throws -> String {
        let instructions = PromptStore().buildCalendarAgentPrompt(
            task: task,
            snapshot: snapshot,
            configuration: configuration
        )

        var history: [OpenAIInputItem] = [.message(role: "user", content: task)]
        var toolRounds = 0

        while true {
            let request = OpenAIRequest(
                model: configuration.resolvedCalendarAgentModel,
                instructions: instructions,
                tools: CalendarToolExecutor.toolDefinitions,
                input: history
            )
            let response = try await client.createResponse(request, apiKey: apiKey)

            let toolCalls = response.output.functionCalls
            if !toolCalls.isEmpty {
                guard toolRounds < maxToolRounds else {
                    throw OpenAIError.toolLoopLimitExceeded(maxToolRounds)
                }
                toolRounds += 1
                for call in toolCalls {
                    history.append(.functionCall(callId: call.callId, name: call.name, arguments: call.arguments))
                }
                for call in toolCalls {
                    let input = parseArguments(call.arguments)
                    let output = await toolExecutor.execute(name: call.name, input: input)
                    history.append(.functionCallOutput(callId: call.callId, output: output))
                }
                continue
            }

            let output = response.output.text
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OpenAIError.emptyResponse
            }
            return output
        }
    }

    private func parseArguments(_ arguments: String) -> JSONValue {
        let data = Data(arguments.utf8)
        return (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .object([:])
    }
}
