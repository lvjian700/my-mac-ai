import Foundation

public enum CalendarStoreError: LocalizedError, Equatable {
    case accessDenied
    case calendarNotFound(String)
    case eventNotFound(String)
    case noWritableCalendar
    case invalidEventDraft(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is denied. Grant access in System Settings > Privacy & Security > Calendars."
        case .calendarNotFound(let title):
            return "Calendar '\(title)' not found."
        case .eventNotFound(let id):
            return "Event '\(id)' not found."
        case .noWritableCalendar:
            return "No writable calendar is available."
        case .invalidEventDraft(let message):
            return message
        }
    }
}

@MainActor
public protocol CalendarStore: AnyObject {
    func accessStatus() -> CalendarAccessStatus
    func requestAccess() async throws
    func listCalendars() throws -> [CalendarInfo]
    func listEvents(range: CalendarQuery) throws -> [CalendarEvent]
    func createEvent(_ draft: EventDraft) throws -> CalendarEvent
    func updateEvent(_ update: EventUpdate) throws -> CalendarEvent
}

public extension CalendarStore {
    func validate(_ draft: EventDraft) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw CalendarStoreError.invalidEventDraft("Event title is required.")
        }
        guard draft.endDate > draft.startDate else {
            throw CalendarStoreError.invalidEventDraft("Event end date must be after start date.")
        }
    }
}
