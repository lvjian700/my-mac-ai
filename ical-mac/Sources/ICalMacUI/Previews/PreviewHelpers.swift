#if DEBUG
import Foundation
import ICalMacCore

// MARK: - Fake stores

@MainActor
final class PreviewCalendarStore: CalendarStore {
    var status: CalendarAccessStatus
    var calendars: [CalendarInfo]
    var events: [CalendarEvent]

    init(
        status: CalendarAccessStatus = .granted,
        calendars: [CalendarInfo] = PreviewData.calendars,
        events: [CalendarEvent] = PreviewData.events
    ) {
        self.status = status
        self.calendars = calendars
        self.events = events
    }

    func accessStatus() -> CalendarAccessStatus { status }
    func requestAccess() async throws { status = .granted }
    func listCalendars() throws -> [CalendarInfo] { calendars }
    func listEvents(range: CalendarQuery) throws -> [CalendarEvent] { events }

    func createEvent(_ draft: EventDraft) throws -> CalendarEvent {
        let event = CalendarEvent(
            id: UUID().uuidString,
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate,
            isAllDay: draft.isAllDay,
            calendarTitle: draft.calendarTitle ?? "Personal"
        )
        events.append(event)
        return event
    }

    func updateEvent(_ update: EventUpdate) throws -> CalendarEvent {
        guard var event = events.first(where: { $0.id == update.id }) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }
        if let title = update.title { event.title = title }
        if let start = update.startDate { event.startDate = start }
        if let end = update.endDate { event.endDate = end }
        return event
    }
}

struct PreviewAPIKeyStore: APIKeyStore {
    func readAPIKey() -> String? { "preview-key" }
    func writeAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
}

struct PreviewOpenAIClient: OpenAIClient {
    func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse {
        OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Preview response")])])
    }
}

// MARK: - Sample data

enum PreviewData {
    static let now = Date()

    static let calendars: [CalendarInfo] = [
        CalendarInfo(id: "1", title: "Personal", accountName: "iCloud", allowsContentModifications: true),
        CalendarInfo(id: "2", title: "Work", accountName: "Google", allowsContentModifications: true),
        CalendarInfo(id: "3", title: "Holidays", accountName: "iCloud", allowsContentModifications: false),
    ]

    static let events: [CalendarEvent] = [
        CalendarEvent(
            id: "e1",
            title: "Team Standup",
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            isAllDay: false,
            calendarTitle: "Work"
        ),
        CalendarEvent(
            id: "e2",
            title: "Lunch with Sarah",
            startDate: now.addingTimeInterval(14400),
            endDate: now.addingTimeInterval(18000),
            isAllDay: false,
            calendarTitle: "Personal"
        ),
        CalendarEvent(
            id: "e3",
            title: "Product Review",
            startDate: now.addingTimeInterval(86400),
            endDate: now.addingTimeInterval(90000),
            isAllDay: false,
            calendarTitle: "Work"
        ),
    ]

    static let messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule."),
        ChatMessage(role: .user, text: "What's on my calendar today?"),
        ChatMessage(role: .assistant, text: "You have Team Standup now and Lunch with Sarah at 1 PM."),
    ]
}

// MARK: - AppModel factory

extension AppModel {
    @MainActor
    static func preview(
        status: CalendarAccessStatus = .granted,
        events: [CalendarEvent] = PreviewData.events,
        calendars: [CalendarInfo] = PreviewData.calendars,
        messages: [ChatMessage] = PreviewData.messages
    ) -> AppModel {
        let model = AppModel(
            calendarStore: PreviewCalendarStore(status: status, calendars: calendars, events: events),
            memoryStore: MemoryStore(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ical-mac-preview")),
            promptStore: PromptStore(),
            apiKeyStore: PreviewAPIKeyStore(),
            client: PreviewOpenAIClient()
        )
        model.events = events
        model.calendars = calendars
        model.accessStatus = status
        model.statusText = "Synced 9:00 AM"
        model.messages = messages
        model.apiKeyDraft = "preview-key"
        return model
    }
}
#endif
