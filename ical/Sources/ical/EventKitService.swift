@preconcurrency import EventKit
import Foundation

enum IcalError: LocalizedError {
    case accessDenied
    case calendarNotFound(name: String)
    case noDefaultCalendar
    case invalidDate(string: String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to Calendar. Grant permission in System Settings > Privacy & Security > Calendars."
        case .calendarNotFound(let n):
            return "Calendar '\(n)' not found."
        case .noDefaultCalendar:
            return "No default calendar found. Specify one with --calendar."
        case .invalidDate(let s):
            return "Cannot parse date '\(s)'. Use ISO-8601 (e.g. 2026-04-15T14:00:00) or 'today'/'tomorrow'."
        }
    }
}

@MainActor
final class EventKitService {
    static let shared = EventKitService()
    private let store = EKEventStore()

    private init() {}

    // MARK: - Permissions

    func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw IcalError.accessDenied }
    }

    // MARK: - Calendars

    func listCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    // MARK: - Events

    func listEvents(
        from startDate: Date,
        to endDate: Date,
        calendars calendarNames: [String] = []
    ) -> [EKEvent] {
        let cals: [EKCalendar]? = calendarNames.isEmpty
            ? nil
            : resolveCalendars(named: calendarNames)
        let pred = store.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    func addEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarName: String?,
        location: String?,
        notes: String?,
        allDay: Bool
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = allDay
        event.location = location
        event.notes = notes
        event.calendar = try resolveTargetCalendar(named: calendarName)
        try store.save(event, span: .thisEvent)
        return event
    }

    // MARK: - Helpers

    private func resolveCalendars(named names: [String]) -> [EKCalendar] {
        let all = store.calendars(for: .event)
        return names.compactMap { name in
            all.first { $0.title.lowercased() == name.lowercased() }
        }
    }

    private func resolveTargetCalendar(named name: String?) throws -> EKCalendar {
        if let name {
            let all = store.calendars(for: .event)
            guard let cal = all.first(where: { $0.title.lowercased() == name.lowercased() }) else {
                throw IcalError.calendarNotFound(name: name)
            }
            return cal
        } else {
            guard let cal = store.defaultCalendarForNewEvents else {
                throw IcalError.noDefaultCalendar
            }
            return cal
        }
    }
}
