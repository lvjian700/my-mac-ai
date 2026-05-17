import Foundation

@MainActor
public final class CalendarToolExecutor {
    private let calendarStore: CalendarStore
    private let memoryStore: MemoryStore
    private let dateParser: CalendarDateParser
    private let defaultCalendarTitle: String?
    private let encoder: JSONEncoder

    public init(
        calendarStore: CalendarStore,
        memoryStore: MemoryStore,
        dateParser: CalendarDateParser = CalendarDateParser(),
        defaultCalendarTitle: String? = nil
    ) {
        self.calendarStore = calendarStore
        self.memoryStore = memoryStore
        self.dateParser = dateParser
        self.defaultCalendarTitle = defaultCalendarTitle?.isEmpty == false ? defaultCalendarTitle : nil
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public static var toolDefinitions: [AnthropicToolDefinition] {
        [
            AnthropicToolDefinition(
                name: "list_calendars",
                description: "List available Apple calendars.",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            ),
            AnthropicToolDefinition(
                name: "list_events",
                description: "List Apple Calendar events. Provide from/to as YYYY-MM-DD, ISO-8601, today, or tomorrow.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "from": .object(["type": .string("string")]),
                        "to": .object(["type": .string("string")]),
                        "calendars": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                    ]),
                    "required": .array([.string("from"), .string("to")]),
                ])
            ),
            AnthropicToolDefinition(
                name: "create_event",
                description: "Create an Apple Calendar event.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["type": .string("string")]),
                        "start": .object(["type": .string("string")]),
                        "end": .object(["type": .string("string")]),
                        "calendar": .object(["type": .string("string")]),
                        "location": .object(["type": .string("string")]),
                        "notes": .object(["type": .string("string")]),
                        "all_day": .object(["type": .string("boolean")]),
                    ]),
                    "required": .array([.string("title"), .string("start"), .string("end")]),
                ])
            ),
            AnthropicToolDefinition(
                name: "update_event",
                description: "Update an existing Apple Calendar event by id.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "id": .object(["type": .string("string")]),
                        "title": .object(["type": .string("string")]),
                        "start": .object(["type": .string("string")]),
                        "end": .object(["type": .string("string")]),
                        "calendar": .object(["type": .string("string")]),
                        "location": .object(["type": .string("string")]),
                        "notes": .object(["type": .string("string")]),
                        "all_day": .object(["type": .string("boolean")]),
                    ]),
                    "required": .array([.string("id")]),
                ])
            ),
            AnthropicToolDefinition(
                name: "write_memory",
                description: "Write the full YAML calendar memory content.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object(["content": .object(["type": .string("string")])]),
                    "required": .array([.string("content")]),
                ])
            ),
        ]
    }

    public func execute(name: String, input: JSONValue) async -> String {
        do {
            let object = input.objectValue ?? [:]
            switch name {
            case "list_calendars":
                return try encode(calendarStore.listCalendars())
            case "list_events":
                let query = try makeQuery(from: object)
                return try encode(calendarStore.listEvents(range: query))
            case "create_event":
                let event = try calendarStore.createEvent(makeDraft(from: object))
                return try encode(event)
            case "update_event":
                let event = try calendarStore.updateEvent(makeUpdate(from: object))
                return try encode(event)
            case "write_memory":
                try memoryStore.writeMemory(requiredString("content", in: object))
                return "Saved to \(memoryStore.memoryURL.path)"
            default:
                return "Unknown tool: \(name)"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func makeQuery(from object: [String: JSONValue]) throws -> CalendarQuery {
        var query = try dateParser.query(
            from: requiredString("from", in: object),
            to: requiredString("to", in: object)
        )
        query.calendarTitles = object["calendars"]?.arrayValue?.compactMap(\.stringValue) ?? []
        return query
    }

    private func makeDraft(from object: [String: JSONValue]) throws -> EventDraft {
        EventDraft(
            title: try requiredString("title", in: object),
            startDate: try dateParser.parse(requiredString("start", in: object)),
            endDate: try dateParser.parse(requiredString("end", in: object)),
            calendarTitle: object["calendar"]?.stringValue ?? defaultCalendarTitle,
            location: object["location"]?.stringValue,
            notes: object["notes"]?.stringValue,
            isAllDay: object["all_day"]?.boolValue ?? false
        )
    }

    private func makeUpdate(from object: [String: JSONValue]) throws -> EventUpdate {
        let start = try object["start"]?.stringValue.map { try dateParser.parse($0) }
        let end = try object["end"]?.stringValue.map { try dateParser.parse($0) }
        return EventUpdate(
            id: try requiredString("id", in: object),
            title: object["title"]?.stringValue,
            startDate: start,
            endDate: end,
            calendarTitle: object["calendar"]?.stringValue,
            location: object["location"]?.stringValue,
            notes: object["notes"]?.stringValue,
            isAllDay: object["all_day"]?.boolValue
        )
    }

    private func requiredString(_ key: String, in object: [String: JSONValue]) throws -> String {
        guard let value = object[key]?.stringValue, !value.isEmpty else {
            throw CalendarStoreError.invalidEventDraft("Missing required field '\(key)'.")
        }
        return value
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
