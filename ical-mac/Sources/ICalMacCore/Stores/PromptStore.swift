import Foundation

public struct PromptStore: Sendable {
    public var skillDirectory: URL?
    public var calendarRulesURL: URL?

    public init(skillDirectory: URL? = PromptStore.defaultSkillDirectory()) {
        self.skillDirectory = skillDirectory
        self.calendarRulesURL = skillDirectory?.appendingPathComponent("references/calendar_rules.md")
    }

    public func buildSystemPrompt(
        memory: String,
        snapshot: SessionSnapshot?,
        configuration: AssistantConfiguration = AssistantConfiguration(),
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let skill = loadSkillPrompt()
        let rules = loadCalendarRules()
        let date = Self.dateFormatter().string(from: now)
        let memoryText = memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "# no ical memory found"
            : "# memory: ~/.my-mac-ai/ical/memory.yaml\n\(memory)"
        let snapshotText = snapshot.map(Self.formatSnapshot(_:))
            ?? "## Calendar Snapshot\n\nNo snapshot available. Use calendar tools for calendar queries."

        return [
            skill,
            "## Response Style\nLead with what matters. Keep answers short, direct, and calendar-focused.",
            "## Calendar Rules Reference\n\(rules)",
            "## Loaded Memory\n\(memoryText)",
            "## Session Context\nToday is \(date). Timezone: \(timeZone.identifier).\(configuration.userName.map { " The user's name is \($0)." } ?? "")",
            snapshotText,
        ].joined(separator: "\n\n")
    }

    public func loadSkillPrompt() -> String {
        guard let skillDirectory else { return Self.fallbackPrompt }
        let url = skillDirectory.appendingPathComponent("SKILL.md")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return Self.fallbackPrompt
        }
        return Self.removeCommandsSection(from: Self.stripFrontmatter(content))
    }

    public func loadCalendarRules() -> String {
        guard let calendarRulesURL,
              let content = try? String(contentsOf: calendarRulesURL, encoding: .utf8) else {
            return "No saved calendar rules reference was found."
        }
        return content
    }

    public static func stripFrontmatter(_ content: String) -> String {
        guard content.hasPrefix("---"),
              let end = content.range(of: "\n---", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) else {
            return content
        }
        return String(content[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func removeCommandsSection(from content: String) -> String {
        guard let start = content.range(of: "\n## Commands\n") else { return content }
        let searchRange = start.upperBound..<content.endIndex
        if let end = content.range(of: "\n## ", range: searchRange) {
            return String(content[..<start.lowerBound] + content[end.lowerBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(content[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
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

    public static func defaultSkillDirectory() -> URL? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent("../ical/.claude/skills/ical").standardizedFileURL,
            cwd.appendingPathComponent("ical/.claude/skills/ical").standardizedFileURL,
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/skills/ical"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/skills/ical"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("SKILL.md").path) }
    }

    private static let fallbackPrompt = """
    # Cali

    You are a direct, helpful calendar assistant for Apple Calendar. Answer briefly and use tools for current calendar data and mutations.
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
