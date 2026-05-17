import Foundation
@testable import ICalMacCore

func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("ical-mac-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

@MainActor
final class FakeCalendarStore: CalendarStore {
    var status: CalendarAccessStatus = .granted
    var calendars: [CalendarInfo] = []
    var events: [CalendarEvent] = []
    var lastQuery: CalendarQuery?
    var createdDrafts: [EventDraft] = []
    var updates: [EventUpdate] = []

    func accessStatus() -> CalendarAccessStatus {
        status
    }

    func requestAccess() async throws {
        status = .granted
    }

    func listCalendars() throws -> [CalendarInfo] {
        calendars
    }

    func listEvents(range: CalendarQuery) throws -> [CalendarEvent] {
        lastQuery = range
        return events
    }

    func createEvent(_ draft: EventDraft) throws -> CalendarEvent {
        try validate(draft)
        createdDrafts.append(draft)
        let event = CalendarEvent(
            id: "created-\(createdDrafts.count)",
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate,
            isAllDay: draft.isAllDay,
            calendarTitle: draft.calendarTitle ?? "Default"
        )
        events.append(event)
        return event
    }

    func updateEvent(_ update: EventUpdate) throws -> CalendarEvent {
        updates.append(update)
        guard var event = events.first(where: { $0.id == update.id }) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }
        if let title = update.title { event.title = title }
        if let startDate = update.startDate { event.startDate = startDate }
        if let endDate = update.endDate { event.endDate = endDate }
        return event
    }
}

final class FakeAnthropicClient: AnthropicClient, @unchecked Sendable {
    private var responses: [AnthropicMessageResponse]
    private(set) var requests: [AnthropicMessageRequest] = []

    init(responses: [AnthropicMessageResponse]) {
        self.responses = responses
    }

    func createMessage(_ request: AnthropicMessageRequest, apiKey: String) async throws -> AnthropicMessageResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}

struct FakeAPIKeyStore: APIKeyStore {
    var key: String?

    func readAPIKey() -> String? {
        key
    }

    func writeAPIKey(_ key: String) throws {}

    func deleteAPIKey() throws {}
}
