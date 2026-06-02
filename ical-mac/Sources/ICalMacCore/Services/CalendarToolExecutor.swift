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

    public static var toolDefinitions: [OpenAIToolDefinition] {
        [
            OpenAIToolDefinition(
                name: "list_calendars",
                description: "List available Apple calendars.",
                parameters: .object(["type": .string("object"), "properties": .object([:])])
            ),
            OpenAIToolDefinition(
                name: "list_events",
                description: "List Apple Calendar events. Provide from/to as YYYY-MM-DD, ISO-8601, today, or tomorrow.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "from": .object(["type": .string("string")]),
                        "to": .object(["type": .string("string")]),
                        "calendars": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                    ]),
                    "required": .array([.string("from"), .string("to")]),
                ])
            ),
            OpenAIToolDefinition(
                name: "create_event",
                description: "Create an Apple Calendar event.",
                parameters: .object([
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
            OpenAIToolDefinition(
                name: "update_event",
                description: "Update an existing Apple Calendar event by id.",
                parameters: .object([
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
            OpenAIToolDefinition(
                name: "delete_event",
                description: "Delete an existing Apple Calendar event by id.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "id": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("id")]),
                ])
            ),
            OpenAIToolDefinition(
                name: "write_memory",
                description: "Write the full YAML calendar memory content.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object(["content": .object(["type": .string("string")])]),
                    "required": .array([.string("content")]),
                ])
            ),
            OpenAIToolDefinition(
                name: "respond_to_invite",
                description: "Accept, decline, or tentatively accept a calendar invitation by event id.",
                parameters: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "id": .object(["type": .string("string")]),
                        "response": .object([
                            "type": .string("string"),
                            "enum": .array([.string("accept"), .string("decline"), .string("tentative")]),
                        ]),
                    ]),
                    "required": .array([.string("id"), .string("response")]),
                ])
            ),
        ]
    }

    public func execute(name: String, input: JSONValue) async -> String {
        do {
            let object = input.objectValue ?? [:]
            switch name {
            case "list_calendars":
                return try await encode(calendarStore.listCalendars())
            case "list_events":
                let query = try makeQuery(from: object)
                return try await encode(calendarStore.listEvents(range: query))
            case "create_event":
                let event = try await calendarStore.createEvent(makeDraft(from: object))
                return try encode(event)
            case "update_event":
                let event = try await calendarStore.updateEvent(makeUpdate(from: object))
                return try encode(event)
            case "delete_event":
                let event = try await calendarStore.deleteEvent(id: requiredString("id", in: object))
                return try encode(event)
            case "write_memory":
                try memoryStore.writeMemory(requiredString("content", in: object))
                return "Saved to \(memoryStore.memoryURL.path)"
            case "respond_to_invite":
                let id = try requiredString("id", in: object)
                let responseStr = try requiredString("response", in: object)
                guard let response = CalendarInvitationResponse(rawValue: responseStr) else {
                    return "Error: invalid response '\(responseStr)'. Use accept, decline, or tentative."
                }
                let event = try await calendarStore.respondToInvitation(id: id, response: response)
                return try encode(event)
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
