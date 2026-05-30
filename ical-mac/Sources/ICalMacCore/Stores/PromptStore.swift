import Foundation

public struct PromptStore: Sendable {
    public init() {}

    // System prompt for the ChatAgent (Cali): personality, orchestration, memory, snapshot context.
    public func buildSystemPrompt(
        memory: String,
        snapshot: SessionSnapshot?,
        configuration: AssistantConfiguration = AssistantConfiguration(),
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let date = Self.dateFormatter().string(from: now)
        let memoryText = memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "# no ical memory found"
            : "# memory: ~/.my-mac-ai/ical/memory.yaml\n\(memory)"
        let snapshotText = snapshot.map(Self.formatSnapshot(_:))
            ?? "## Calendar Snapshot\n\nNo snapshot available. Use calendar_agent for calendar queries."

        return [
            Self.caliPrompt,
            "## Loaded Memory\n\(memoryText)",
            "## Session Context\nToday is \(date). Timezone: \(timeZone.identifier).\(configuration.userName.map { " The user's name is \($0)." } ?? "")",
            snapshotText,
        ].joined(separator: "\n\n")
    }

    // System prompt for the CalendarAgent: task-focused, no personality, efficient tool use.
    public func buildCalendarAgentPrompt(
        task: String,
        snapshot: SessionSnapshot?,
        configuration: AssistantConfiguration = AssistantConfiguration(),
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let date = Self.dateFormatter().string(from: now)
        let snapshotText = snapshot.map(Self.formatSnapshot(_:))
            ?? "## Calendar Snapshot\n\nNo snapshot available."

        return [
            Self.calendarAgentPrompt,
            "## Session Context\nToday is \(date). Timezone: \(timeZone.identifier).\(configuration.userName.map { " The user's name is \($0)." } ?? "")",
            snapshotText,
            "## Task\n\(task)",
        ].joined(separator: "\n\n")
    }

    public static func formatSnapshot(_ snapshot: SessionSnapshot) -> String {
        let dateFormatter = dateFormatter()
        let dateTimeFormatter = dateTimeFormatter()
        let range = "\(dateFormatter.string(from: snapshot.range.startDate)) to \(dateFormatter.string(from: snapshot.range.endDate))"
        var lines = ["## Calendar Snapshot", "Synced \(dateTimeFormatter.string(from: snapshot.syncedAt)); range \(range)."]
        if snapshot.events.isEmpty {
            lines.append("No events in this range.")
        } else {
            lines.append(contentsOf: snapshot.events.map { event in
                "- \(dateTimeFormatter.string(from: event.startDate)) - \(dateTimeFormatter.string(from: event.endDate)): \(event.title) [\(event.calendarTitle)]"
            })
        }
        lines.append("Use these events for this range. Use calendar tools for dates outside this range or for mutations.")
        return lines.joined(separator: "\n")
    }

    // ChatAgent prompt: Cali personality + orchestration guidance for calendar_agent delegation.
    private static let caliPrompt = """
    # Cali

    You are Cali, a calendar assistant inside the native ical-mac app. You sound like a smart friend who happens to have access to the user's Apple Calendar. You are on their side. Not a bot, not a corporate assistant.

    ## Personality
    - Warm but not clingy. Care without overdoing it. No "Great question" energy.
    - Smart but not smug. Notice schedule problems proactively without lecturing.
    - Direct. Short sentences. No corporate fluff.
    - Gently protective. Nudge toward rest, focus time, and boundaries when the calendar looks rough. Say it once, then move on.
    - Dry wit is fine when it fits, but do not force it.

    ## Calendar Operations
    - Use the `calendar_agent` tool to delegate all calendar queries and mutations. Do not try to use the `ical` CLI, shell commands, or any external tools.
    - Use the calendar snapshot to answer questions about the visible week without a tool call. Delegate to `calendar_agent` for dates outside the snapshot, mutations, conflict checks, or unknown calendars.
    - When delegating, describe the task clearly: include exact dates, calendar names, event titles or IDs, the required action, and any context from the conversation the agent needs.
    - Present the calendar agent's result in your voice. Don't restate facts already in the result — just deliver what matters.

    ## Response Style
    - Lead with what matters: the event, conflict, gap, or action result.
    - Never start a response with "I".
    - Confirm actions simply: "Done." or "It's on your calendar."
    - No filler: never use "Certainly", "Of course", "I'd be happy to help", or "Is there anything else I can assist you with?"
    - Keep answers short, direct, and calendar-focused.
    - Highlight times with markdown bold text.
    """

    // CalendarAgent prompt: specialist persona, efficient tool use, factual output.
    private static let calendarAgentPrompt = """
    # Calendar Agent

    You are a calendar operations specialist. Complete the given task using the available Apple Calendar tools. Be efficient — use the minimum number of tool calls needed.

    - Check for conflicts before creating or moving events.
    - List calendars if you need to identify one by name.
    - Return a concise, factual summary of what you did and the result.
    - Do not add filler, ask follow-up questions, or explain your reasoning. Just complete the task and report the outcome.
    """

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func dateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
}
