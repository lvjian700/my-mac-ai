@preconcurrency import EventKit
import Foundation

enum IcalError: LocalizedError {
    case accessDenied
    case calendarNotFound(name: String)
    case accountNotFound(name: String)
    case noDefaultCalendar
    case invalidDate(string: String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to Calendar. Grant permission in System Settings > Privacy & Security > Calendars."
        case .calendarNotFound(let n):
            return "Calendar '\(n)' not found."
        case .accountNotFound(let n):
            return "Account '\(n)' not found. Use `ical list` to see available accounts."
        case .noDefaultCalendar:
            return "No default calendar found. Specify one with --calendar."
        case .invalidDate(let s):
            return "Cannot parse date '\(s)'. Use ISO-8601 (e.g. 2026-04-15T14:00:00) or 'today'/'tomorrow'."
        }
    }
}

struct CalendarGroup {
    let accountName: String
    let calendars: [EKCalendar]
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

    func listCalendarsGrouped(account: String? = nil) throws -> [CalendarGroup] {
        var sources = store.sources
            .filter { !$0.calendars(for: .event).isEmpty }
            .sorted { $0.title < $1.title }
        if let account {
            sources = sources.filter { $0.title.lowercased() == account.lowercased() }
            if sources.isEmpty { throw IcalError.accountNotFound(name: account) }
        }
        return sources.map { source in
            CalendarGroup(
                accountName: source.title,
                calendars: source.calendars(for: .event).sorted { $0.title < $1.title }
            )
        }
    }

    // MARK: - Events

    func listEvents(
        from startDate: Date,
        to endDate: Date,
        calendars calendarNames: [String] = [],
        account: String? = nil
    ) throws -> [EKEvent] {
        let cals: [EKCalendar]?
        if account != nil || !calendarNames.isEmpty {
            cals = try resolveCalendars(named: calendarNames, account: account)
        } else {
            cals = nil
        }
        let pred = store.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    func addEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarName: String?,
        account: String? = nil,
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
        event.calendar = try resolveTargetCalendar(named: calendarName, account: account)
        try store.save(event, span: .thisEvent)
        return event
    }

    // MARK: - Helpers

    private func resolveCalendars(named names: [String], account: String? = nil) throws -> [EKCalendar] {
        var all = store.calendars(for: .event)
        if let account {
            all = all.filter { $0.source?.title.lowercased() == account.lowercased() }
            if all.isEmpty { throw IcalError.accountNotFound(name: account) }
        }
        if names.isEmpty { return all }
        return names.compactMap { name in all.first { $0.title.lowercased() == name.lowercased() } }
    }

    private func resolveTargetCalendar(named name: String?, account: String? = nil) throws -> EKCalendar {
        if let name {
            var all = store.calendars(for: .event)
            if let account {
                all = all.filter { $0.source?.title.lowercased() == account.lowercased() }
                if all.isEmpty { throw IcalError.accountNotFound(name: account) }
            }
            guard let cal = all.first(where: { $0.title.lowercased() == name.lowercased() }) else {
                throw IcalError.calendarNotFound(name: name)
            }
            return cal
        } else if let account {
            let all = store.calendars(for: .event).filter { $0.source?.title.lowercased() == account.lowercased() }
            if all.isEmpty { throw IcalError.accountNotFound(name: account) }
            guard let cal = all.first(where: { $0.calendarIdentifier == store.defaultCalendarForNewEvents?.calendarIdentifier })
                ?? all.first else {
                throw IcalError.noDefaultCalendar
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
