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
    func listCalendars() async throws -> [CalendarInfo] { calendars }
    func listEvents(range: CalendarQuery) async throws -> [CalendarEvent] { events }

    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
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

    func updateEvent(_ update: EventUpdate) async throws -> CalendarEvent {
        guard let index = events.firstIndex(where: { $0.id == update.id }) else {
            throw CalendarStoreError.eventNotFound(update.id)
        }
        var event = events[index]
        if let title = update.title { event.title = title }
        if let start = update.startDate { event.startDate = start }
        if let end = update.endDate { event.endDate = end }
        events[index] = event
        return event
    }

    func deleteEvent(id: String) async throws -> CalendarEvent {
        guard let index = events.firstIndex(where: { $0.id == id }) else {
            throw CalendarStoreError.eventNotFound(id)
        }
        return events.remove(at: index)
    }

    func respondToInvitation(id: String, response: CalendarInvitationResponse) async throws -> CalendarEvent {
        guard let event = events.first(where: { $0.id == id }) else {
            throw CalendarStoreError.eventNotFound(id)
        }
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

    static let events: [CalendarEvent] = categoryEvents + shortEvents + clashEvents + recurringEvents

    static let categoryEvents: [CalendarEvent] = [
        event(
            id: "cat-focus",
            title: "Focus - Planning",
            dayOffset: 0,
            hour: 9,
            minute: 45,
            duration: 60
        ),
        event(
            id: "cat-focus-time",
            title: "Focus time - Deep work",
            dayOffset: 0,
            hour: 13,
            duration: 90
        ),
        event(
            id: "cat-catchup",
            title: "Catchup - Design sync",
            dayOffset: 1,
            hour: 9,
            minute: 45,
            duration: 45
        ),
        event(
            id: "cat-sync",
            title: "Sync: Launch notes",
            dayOffset: 1,
            hour: 11,
            duration: 45
        ),
        event(
            id: "cat-tech-huddle",
            title: "Tech Huddle - Runtime",
            dayOffset: 1,
            hour: 13,
            duration: 45
        ),
        event(
            id: "cat-support",
            title: "Support - Rotation handoff",
            dayOffset: 3,
            hour: 11,
            minute: 30,
            duration: 60
        ),
        event(
            id: "cat-cop",
            title: "Cop - Incident review",
            dayOffset: 3,
            hour: 13,
            duration: 60
        ),
        event(
            id: "cat-oncall",
            title: "Oncall - Primary",
            dayOffset: 4,
            hour: 11,
            duration: 60
        ),
        event(
            id: "cat-meeting",
            title: "Product review",
            dayOffset: 3,
            hour: 10,
            duration: 60
        ),
        event(
            id: "cat-lunch",
            title: "Lunch with Sarah",
            dayOffset: 4,
            hour: 12,
            minute: 15,
            duration: 60,
            calendarTitle: "Personal",
            calendarIdentifier: "1"
        ),
        event(
            id: "cat-personal",
            title: "Personal - School pickup",
            dayOffset: 4,
            hour: 13,
            minute: 30,
            duration: 45,
            calendarTitle: "Personal",
            calendarIdentifier: "1"
        ),
        event(
            id: "cat-break",
            title: "Break - Walk",
            dayOffset: 5,
            hour: 11,
            duration: 30
        ),
        event(
            id: "cat-offscreen",
            title: "Offscreen - Writing",
            dayOffset: 5,
            hour: 14,
            duration: 60
        ),
        allDayEvent(
            id: "cat-out-of-office",
            title: "Out of office - Travel day",
            dayOffset: 6
        ),
    ]

    static let clashEvents: [CalendarEvent] = [
        event(
            id: "clash-two-design-review",
            title: "Catchup - Design review",
            dayOffset: 5,
            hour: 15,
            duration: 60
        ),
        event(
            id: "clash-two-customer-call",
            title: "Support - Customer call",
            dayOffset: 5,
            hour: 15,
            duration: 60
        ),
        event(
            id: "clash-three-release-plan",
            title: "Focus - Release plan",
            dayOffset: 5,
            hour: 16,
            minute: 15,
            duration: 60
        ),
        event(
            id: "clash-three-partner-sync",
            title: "Sync: Partner review",
            dayOffset: 5,
            hour: 16,
            minute: 15,
            duration: 60
        ),
        event(
            id: "clash-three-personal-appointment",
            title: "Personal - Appointment",
            dayOffset: 5,
            hour: 16,
            minute: 15,
            duration: 60,
            calendarTitle: "Personal",
            calendarIdentifier: "1"
        ),
    ]

    static let shortEvents: [CalendarEvent] = [
        event(
            id: "short-five-minute-check",
            title: "Focus - 5 min check",
            dayOffset: 2,
            hour: 14,
            duration: 5
        ),
        event(
            id: "short-ten-minute-check",
            title: "Sync: 10 min check",
            dayOffset: 2,
            hour: 14,
            minute: 10,
            duration: 10
        ),
        event(
            id: "short-fifteen-minute-check",
            title: "Break - 15 min reset",
            dayOffset: 2,
            hour: 14,
            minute: 25,
            duration: 15
        ),
    ]

    static let recurringEvents: [CalendarEvent] =
        weekdayRecurringEvents(
            idPrefix: "recurring-school-time",
            title: "Out of office - school time",
            dayOffsets: 0...4,
            hour: 8,
            duration: 90
        )
        + weekdayRecurringEvents(
            idPrefix: "recurring-school-pickup-tue-fri",
            title: "Out of office - school pickup",
            dayOffsets: 1...4,
            hour: 15,
            duration: 60
        )
        + [
            event(
                id: "recurring-school-pickup-monday",
                title: "Out of office - school pickup",
                dayOffset: 0,
                hour: 16,
                minute: 45,
                duration: 135,
                isRecurring: true
            ),
            event(
                id: "recurring-focus-meeting-free-day",
                title: "Focus - meeting free day",
                dayOffset: 2,
                hour: 9,
                minute: 30,
                duration: 150,
                isRecurring: true
            ),
            event(
                id: "recurring-meet-free-wednesday",
                title: "Meet Free Wednesday",
                dayOffset: 2,
                hour: 12,
                duration: 180,
                isRecurring: true
            ),
        ]

    static let recurringEventSamples: [CalendarEvent] = [
        event(
            id: "recurring-sample-school-time",
            title: "Out of office - school time",
            dayOffset: 0,
            hour: 8,
            duration: 90,
            isRecurring: true
        ),
        event(
            id: "recurring-sample-school-pickup",
            title: "Out of office - school pickup",
            dayOffset: 1,
            hour: 15,
            duration: 60,
            isRecurring: true
        ),
        event(
            id: "recurring-sample-focus-meeting-free-day",
            title: "Focus - meeting free day",
            dayOffset: 2,
            hour: 9,
            minute: 30,
            duration: 150,
            isRecurring: true
        ),
    ]

    static let visibleWeekStart = weekStart

    static let rsvpEvents: [CalendarEvent] = [
        CalendarEvent(
            id: "e1",
            title: "Pending: Team Standup",
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            isAllDay: false,
            calendarTitle: "Work",
            calendarIdentifier: "2",
            invitation: invitation(status: .pending, organizer: "Alex")
        ),
        CalendarEvent(
            id: "e2",
            title: "Accepted: Lunch with Sarah",
            startDate: now.addingTimeInterval(14400),
            endDate: now.addingTimeInterval(18000),
            isAllDay: false,
            calendarTitle: "Personal",
            calendarIdentifier: "1",
            invitation: invitation(status: .accepted, organizer: "Sarah")
        ),
        CalendarEvent(
            id: "e3",
            title: "Tentative: Product Review",
            startDate: now.addingTimeInterval(86400),
            endDate: now.addingTimeInterval(90000),
            isAllDay: false,
            calendarTitle: "Work",
            calendarIdentifier: "2",
            invitation: invitation(status: .tentative, organizer: "Mina")
        ),
        CalendarEvent(
            id: "e4",
            title: "Declined: Vendor Sync",
            startDate: now.addingTimeInterval(18000),
            endDate: now.addingTimeInterval(21600),
            isAllDay: false,
            calendarTitle: "Work",
            calendarIdentifier: "2",
            invitation: invitation(status: .declined, organizer: "Taylor")
        ),
    ]

    static let messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule."),
        ChatMessage(role: .user, text: "What's on my calendar today?"),
        ChatMessage(role: .assistant, text: "Team Standup is now. Lunch with Sarah is at 1 PM."),
    ]

    private static func invitation(status: CalendarParticipantStatus, organizer: String) -> CalendarInvitationInfo {
        CalendarInvitationInfo(
            currentUserStatus: status,
            organizerName: organizer,
            currentUserName: "Me",
            attendeeCount: 3
        )
    }

    private static let calendar = Calendar.current
    private static let weekStart = startOfWeek(containing: now)

    private static func event(
        id: String,
        title: String,
        dayOffset: Int,
        hour: Int,
        minute: Int = 0,
        duration: TimeInterval,
        isRecurring: Bool = false,
        calendarTitle: String = "Work",
        calendarIdentifier: String = "2"
    ) -> CalendarEvent {
        let start = date(dayOffset: dayOffset, hour: hour, minute: minute)
        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(duration * 60),
            isAllDay: false,
            isRecurring: isRecurring,
            calendarTitle: calendarTitle,
            calendarIdentifier: calendarIdentifier
        )
    }

    private static func weekdayRecurringEvents(
        idPrefix: String,
        title: String,
        dayOffsets: ClosedRange<Int>,
        hour: Int,
        minute: Int = 0,
        duration: TimeInterval
    ) -> [CalendarEvent] {
        dayOffsets.map { dayOffset in
            event(
                id: "\(idPrefix)-\(dayOffset)",
                title: title,
                dayOffset: dayOffset,
                hour: hour,
                minute: minute,
                duration: duration,
                isRecurring: true
            )
        }
    }

    private static func allDayEvent(
        id: String,
        title: String,
        dayOffset: Int,
        isRecurring: Bool = false,
        calendarTitle: String = "Work",
        calendarIdentifier: String = "2"
    ) -> CalendarEvent {
        let start = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: true,
            isRecurring: isRecurring,
            calendarTitle: calendarTitle,
            calendarIdentifier: calendarIdentifier
        )
    }

    private static func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func startOfWeek(containing date: Date) -> Date {
        let day = calendar.component(.weekday, from: date)
        let daysFromMonday = day == 1 ? 6 : day - 2
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }
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
            conversationStore: JSONConversationStore(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ical-mac-preview")),
            promptStore: PromptStore(),
            apiKeyStore: PreviewAPIKeyStore(),
            client: PreviewOpenAIClient()
        )
        model.events = events
        model.calendars = calendars
        model.accessStatus = status
        model.displayedWeekStartDate = PreviewData.visibleWeekStart
        model.statusText = "Synced 9:00 AM"
        model.messages = messages
        model.apiKeyDraft = "preview-key"
        return model
    }
}
#endif
