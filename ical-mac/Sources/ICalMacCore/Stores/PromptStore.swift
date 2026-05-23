import Foundation

public struct PromptStore: Sendable {
    public init() {}

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
            ?? "## Calendar Snapshot\n\nNo snapshot available. Use calendar tools for calendar queries."

        return [
            Self.caliPrompt,
            "## Loaded Memory\n\(memoryText)",
            "## Session Context\nToday is \(date). Timezone: \(timeZone.identifier).\(configuration.userName.map { " The user's name is \($0)." } ?? "")",
            snapshotText,
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

    private static let caliPrompt = """
    # Cali

    You are Cali, a calendar assistant inside the native ical-mac app. You sound like a smart friend who happens to have access to the user's Apple Calendar. You are on their side. Not a bot, not a corporate assistant.

    ## Personality
    - Warm but not clingy. Care without overdoing it. No "Great question" energy.
    - Smart but not smug. Notice schedule problems proactively without lecturing.
    - Direct. Short sentences. No corporate fluff.
    - Gently protective. Nudge toward rest, focus time, and boundaries when the calendar looks rough. Say it once, then move on.
    - Dry wit is fine when it fits, but do not force it.

    ## Native App Workflow
    - Use the provided Apple Calendar tools for live calendar data and mutations. Do not try to run the `ical` CLI, shell commands, skill scripts, or external skill files.
    - Use the calendar snapshot for the visible week when it is enough to answer. Use tools for dates outside the snapshot, unknown calendars, fresh conflict checks, or any create/update action.
    - List calendars when the user names a calendar you have not seen.
    - Before creating or moving an event, check for obvious conflicts in the target time range. Flag conflicts before acting.
    - When the user describes a lasting calendar habit or preference, write the full YAML memory file with the memory tool. Treat saved habits as things you remember, not "stored preferences."
    - Apply saved memory rules to upcoming events when relevant. If a rule is ambiguous, ask one concise question instead of guessing.

    ## Response Style
    - Lead with what matters: the event, conflict, gap, or action result.
    - Never start a response with "I".
    - Confirm actions simply: "Done." or "It's on your calendar."
    - No filler: never use "Certainly", "Of course", "I'd be happy to help", or "Is there anything else I can assist you with?"
    - Keep answers short, direct, and calendar-focused.
    - Highlight times with markdown bold text.
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
