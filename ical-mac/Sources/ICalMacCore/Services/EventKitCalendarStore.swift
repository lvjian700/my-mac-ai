@preconcurrency import EventKit
import Foundation

@MainActor
public final class EventKitCalendarStore: CalendarStore {
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func accessStatus() -> CalendarAccessStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .granted
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    public func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarStoreError.accessDenied }
    }

    public func listCalendars() throws -> [CalendarInfo] {
        try requireAccess()
        return store.calendars(for: .event)
            .sorted {
                let left = "\($0.source.title)/\($0.title)"
                let right = "\($1.source.title)/\($1.title)"
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    accountName: calendar.source.title,
                    allowsContentModifications: calendar.allowsContentModifications
                )
            }
    }

    public func listEvents(range: CalendarQuery) throws -> [CalendarEvent] {
        try requireAccess()
        let calendars = try resolveCalendars(titles: range.calendarTitles)
        let predicate = store.predicateForEvents(
            withStart: range.startDate,
            end: range.endDate,
            calendars: calendars
        )
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(CalendarEvent.init(event:))
    }

    public func createEvent(_ draft: EventDraft) throws -> CalendarEvent {
        try requireAccess()
        try validate(draft)
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.isAllDay = draft.isAllDay
        event.location = draft.location
        event.notes = draft.notes
        event.calendar = try resolveTargetCalendar(title: draft.calendarTitle)
        try store.save(event, span: .thisEvent)
        return CalendarEvent(event: event)
    }

    public func updateEvent(_ update: EventUpdate) throws -> CalendarEvent {
        try requireAccess()
        guard let event = store.event(withIdentifier: update.id) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }

        if let title = update.title {
            event.title = title
        }
        if let startDate = update.startDate {
            event.startDate = startDate
        }
        if let endDate = update.endDate {
            event.endDate = endDate
        }
        if let calendarTitle = update.calendarTitle {
            event.calendar = try resolveTargetCalendar(title: calendarTitle)
        }
        if let location = update.location {
            event.location = location
        }
        if let notes = update.notes {
            event.notes = notes
        }
        if let isAllDay = update.isAllDay {
            event.isAllDay = isAllDay
        }

        guard event.endDate > event.startDate else {
            throw CalendarStoreError.invalidEventDraft("Event end date must be after start date.")
        }

        try store.save(event, span: .thisEvent)
        return CalendarEvent(event: event)
    }

    private func requireAccess() throws {
        guard accessStatus() == .granted else {
            throw CalendarStoreError.accessDenied
        }
    }

    private func resolveCalendars(titles: [String]) throws -> [EKCalendar]? {
        guard !titles.isEmpty else { return nil }
        let all = store.calendars(for: .event)
        var resolved: [EKCalendar] = []
        for title in titles {
            guard let calendar = all.first(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }) else {
                throw CalendarStoreError.calendarNotFound(title)
            }
            resolved.append(calendar)
        }
        return resolved
    }

    private func resolveTargetCalendar(title: String?) throws -> EKCalendar {
        if let title, !title.isEmpty {
            guard let calendar = store.calendars(for: .event).first(where: {
                $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
            }) else {
                throw CalendarStoreError.calendarNotFound(title)
            }
            guard calendar.allowsContentModifications else {
                throw CalendarStoreError.noWritableCalendar
            }
            return calendar
        }

        guard let calendar = store.defaultCalendarForNewEvents,
              calendar.allowsContentModifications else {
            throw CalendarStoreError.noWritableCalendar
        }
        return calendar
    }
}

private extension CalendarEvent {
    init(event: EKEvent) {
        self.init(
            id: event.eventIdentifier,
            title: event.title ?? "(untitled)",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title ?? "",
            calendarIdentifier: event.calendar?.calendarIdentifier,
            location: event.location,
            notes: event.notes
        )
    }
}
