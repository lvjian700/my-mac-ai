@preconcurrency import EventKit
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// Owns EKEventStore and runs all EventKit queries on its (non-main) executor.
// EKEventStore is created internally to avoid Sendable violations across actor boundaries.
actor CalendarActor {
    private let store = EKEventStore()

    func requestFullAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarStoreError.accessDenied }
    }

    func fetchCalendars() throws -> [CalendarInfo] {
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
                    allowsContentModifications: calendar.allowsContentModifications,
                    colorHex: calendar.cgColor.hexRGB
                )
            }
    }

    func fetchEvents(range: CalendarQuery) throws -> [CalendarEvent] {
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

    func saveNewEvent(_ draft: EventDraft) throws -> CalendarEvent {
        try requireAccess()
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

    func saveUpdatedEvent(_ update: EventUpdate) throws -> CalendarEvent {
        try requireAccess()
        guard let event = store.event(withIdentifier: update.id) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }
        if let title = update.title { event.title = title }
        if let startDate = update.startDate { event.startDate = startDate }
        if let endDate = update.endDate { event.endDate = endDate }
        if let calendarTitle = update.calendarTitle {
            event.calendar = try resolveTargetCalendar(title: calendarTitle)
        }
        if let location = update.location { event.location = location }
        if let notes = update.notes { event.notes = notes }
        if let isAllDay = update.isAllDay { event.isAllDay = isAllDay }
        guard event.endDate > event.startDate else {
            throw CalendarStoreError.invalidEventDraft("Event end date must be after start date.")
        }
        try store.save(event, span: .thisEvent)
        return CalendarEvent(event: event)
    }

    private func requireAccess() throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return
        default:
            throw CalendarStoreError.accessDenied
        }
    }

    private func resolveCalendars(titles: [String]) throws -> [EKCalendar]? {
        guard !titles.isEmpty else { return nil }
        let all = store.calendars(for: .event)
        var resolved: [EKCalendar] = []
        for title in titles {
            guard let cal = all.first(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }) else {
                throw CalendarStoreError.calendarNotFound(title)
            }
            resolved.append(cal)
        }
        return resolved
    }

    private func resolveTargetCalendar(title: String?) throws -> EKCalendar {
        if let title, !title.isEmpty {
            guard let cal = store.calendars(for: .event).first(where: {
                $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
            }) else {
                throw CalendarStoreError.calendarNotFound(title)
            }
            guard cal.allowsContentModifications else {
                throw CalendarStoreError.noWritableCalendar
            }
            return cal
        }
        guard let cal = store.defaultCalendarForNewEvents, cal.allowsContentModifications else {
            throw CalendarStoreError.noWritableCalendar
        }
        return cal
    }
}

// Thin @MainActor bridge that satisfies CalendarStore and delegates to CalendarActor.
@MainActor
public final class EventKitCalendarStore: CalendarStore {
    private let calendarActor = CalendarActor()

    public init() {}

    public func accessStatus() -> CalendarAccessStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .denied
        }
    }

    public func requestAccess() async throws {
        try await calendarActor.requestFullAccess()
    }

    public func listCalendars() async throws -> [CalendarInfo] {
        try await calendarActor.fetchCalendars()
    }

    public func listEvents(range: CalendarQuery) async throws -> [CalendarEvent] {
        try await calendarActor.fetchEvents(range: range)
    }

    public func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        try validate(draft)
        return try await calendarActor.saveNewEvent(draft)
    }

    public func updateEvent(_ update: EventUpdate) async throws -> CalendarEvent {
        try await calendarActor.saveUpdatedEvent(update)
    }
}

#if canImport(CoreGraphics)
private extension CGColor {
    var hexRGB: String? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let color = colorSpace.flatMap { converted(to: $0, intent: .defaultIntent, options: nil) } ?? self
        guard let components = color.components else { return nil }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        switch components.count {
        case 2:
            red = components[0]
            green = components[0]
            blue = components[0]
        case 3, 4:
            red = components[0]
            green = components[1]
            blue = components[2]
        default:
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
#endif

private extension CalendarEvent {
    init(event: EKEvent) {
        self.init(
            id: event.eventIdentifier,
            title: event.title ?? "(untitled)",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isRecurring: event.isRecurringOccurrence,
            calendarTitle: event.calendar?.title ?? "",
            calendarIdentifier: event.calendar?.calendarIdentifier,
            location: event.location,
            notes: event.notes,
            invitation: CalendarInvitationInfo(event: event)
        )
    }
}

private extension EKEvent {
    var isRecurringOccurrence: Bool {
        recurrenceRules?.isEmpty == false || isDetached
    }
}

private extension CalendarInvitationInfo {
    init?(event: EKEvent) {
        guard event.hasAttendees else { return nil }
        let attendees = event.attendees ?? []
        let organizer = event.organizer
        guard organizer?.isCurrentUser != true else { return nil }
        guard let currentUser = attendees.first(where: \.isCurrentUser) else { return nil }

        self.init(
            currentUserStatus: CalendarParticipantStatus(status: currentUser.participantStatus),
            organizerName: organizer?.name,
            organizerURL: organizer?.url.absoluteString,
            currentUserName: currentUser.name,
            currentUserURL: currentUser.url.absoluteString,
            attendeeCount: attendees.count
        )
    }
}

private extension CalendarParticipantStatus {
    init(status: EKParticipantStatus) {
        switch status {
        case .unknown:
            self = .unknown
        case .pending:
            self = .pending
        case .accepted:
            self = .accepted
        case .declined:
            self = .declined
        case .tentative:
            self = .tentative
        case .delegated:
            self = .delegated
        case .completed:
            self = .completed
        case .inProcess:
            self = .inProcess
        @unknown default:
            self = .unknown
        }
    }
}
