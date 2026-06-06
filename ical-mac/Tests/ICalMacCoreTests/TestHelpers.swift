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
    var deletedEventIDs: [String] = []

    func accessStatus() -> CalendarAccessStatus {
        status
    }

    func requestAccess() async throws {
        status = .granted
    }

    func listCalendars() async throws -> [CalendarInfo] {
        calendars
    }

    func listEvents(range: CalendarQuery) async throws -> [CalendarEvent] {
        lastQuery = range
        return events
    }

    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
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

    func updateEvent(_ update: EventUpdate) async throws -> CalendarEvent {
        updates.append(update)
        guard let index = events.firstIndex(where: { $0.id == update.id }) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }
        var event = events[index]
        if let title = update.title { event.title = title }
        if let startDate = update.startDate { event.startDate = startDate }
        if let endDate = update.endDate { event.endDate = endDate }
        events[index] = event
        return event
    }

    func deleteEvent(id: String) async throws -> CalendarEvent {
        guard let index = events.firstIndex(where: { $0.id == id }) else {
            throw CalendarStoreError.eventNotFound(id)
        }
        deletedEventIDs.append(id)
        return events.remove(at: index)
    }

    func respondToInvitation(id: String, response: CalendarInvitationResponse) async throws -> CalendarEvent {
        guard let event = events.first(where: { $0.id == id }) else {
            throw CalendarStoreError.eventNotFound(id)
        }
        return event
    }
}

final class FakeOpenAIClient: OpenAIClient, @unchecked Sendable {
    private var responses: [OpenAIResponse]
    private(set) var requests: [OpenAIRequest] = []

    init(responses: [OpenAIResponse]) {
        self.responses = responses
    }

    func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse {
        requests.append(request)
        return responses.removeFirst()
    }

    func streamResponse(_ request: OpenAIRequest, apiKey: String) async throws -> AsyncThrowingStream<OpenAIStreamEvent, Error> {
        requests.append(request)
        let response = responses.removeFirst()
        let text = response.output.text
        return AsyncThrowingStream { continuation in
            if !text.isEmpty { continuation.yield(.textDelta(text)) }
            continuation.yield(.completed(response))
            continuation.finish()
        }
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
