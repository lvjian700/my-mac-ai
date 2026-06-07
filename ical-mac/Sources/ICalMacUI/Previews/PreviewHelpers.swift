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
    var key: String?
    func readAPIKey() -> String? { key }
    func writeAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
}

struct PreviewOpenAIClient: OpenAIClient {
    func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse {
        OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Preview response")])])
    }

    func streamResponse(_ request: OpenAIRequest, apiKey: String) async throws -> AsyncThrowingStream<OpenAIStreamEvent, Error> {
        let response = OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Preview response")])])
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("Preview response"))
            continuation.yield(.completed(response))
            continuation.finish()
        }
    }
}

actor PreviewConversationStore: ConversationStore {
    private var records: [UUID: ChatConversationRecord]

    init(records: [ChatConversationRecord] = PreviewData.conversations) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    func listSummaries() async throws -> [ConversationSummary] {
        records.values
            .map(\.summary)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadConversation(id: UUID) async throws -> ChatConversationRecord {
        guard let record = records[id] else {
            throw ConversationStoreError.conversationNotFound(id)
        }
        return record
    }

    func createConversation(
        messages: [ChatMessage],
        transcript: [OpenAIInputItem]
    ) async throws -> ChatConversationRecord {
        var record = ChatConversationRecord(messages: messages, transcript: transcript)
        record.refreshMetadata()
        records[record.id] = record
        return record
    }

    func saveConversation(_ conversation: ChatConversationRecord) async throws {
        records[conversation.id] = conversation
    }

    func deleteConversation(id: UUID) async throws {
        records[id] = nil
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

    static let conversations: [ChatConversationRecord] = [
        conversation(
            id: "11111111-1111-1111-1111-111111111111",
            title: "What's the time for WWDC session planning?",
            updatedAt: now.addingTimeInterval(-4 * 3_600),
            messages: [
                ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.", createdAt: now.addingTimeInterval(-4 * 3_600 - 180)),
                ChatMessage(role: .user, text: "What's the time for WWDC session planning?", createdAt: now.addingTimeInterval(-4 * 3_600 - 120)),
                ChatMessage(role: .assistant, text: "Yes, a few things matter next month. WWDC starts Monday morning, and your watch party is blocked for 11 AM.", createdAt: now.addingTimeInterval(-4 * 3_600)),
            ]
        ),
        conversation(
            id: "22222222-2222-2222-2222-222222222222",
            title: "anything happening next week?",
            updatedAt: now.addingTimeInterval(-2 * 86_400),
            messages: [
                ChatMessage(role: .user, text: "anything happening next week?", createdAt: now.addingTimeInterval(-2 * 86_400 - 60)),
                ChatMessage(role: .assistant, text: "Done. Focus time is on Tuesday from 9:30 to noon, with product review on Thursday.", createdAt: now.addingTimeInterval(-2 * 86_400)),
            ]
        ),
        conversation(
            id: "33333333-3333-3333-3333-333333333333",
            title: "watch tv right now",
            updatedAt: now.addingTimeInterval(-7 * 86_400),
            messages: [
                ChatMessage(role: .user, text: "watch tv right now", createdAt: now.addingTimeInterval(-7 * 86_400 - 90)),
                ChatMessage(role: .assistant, text: "Done. Watch TV now runs for 1 hour.", createdAt: now.addingTimeInterval(-7 * 86_400)),
            ]
        ),
        conversation(
            id: "44444444-4444-4444-4444-444444444444",
            title: "Review next week's schedule",
            updatedAt: now.addingTimeInterval(-32 * 86_400),
            messages: [
                ChatMessage(role: .user, text: "Review next week's schedule", createdAt: now.addingTimeInterval(-32 * 86_400 - 120)),
                ChatMessage(role: .assistant, text: "You have a meeting-heavy Monday and Wednesday, with Friday mostly open.", createdAt: now.addingTimeInterval(-32 * 86_400)),
            ]
        ),
        conversation(
            id: "55555555-5555-5555-5555-555555555555",
            title: "What does my week look like?",
            updatedAt: now.addingTimeInterval(-30 * 60),
            messages: longChatMessages
        ),
    ]

    static let emptyChatMessages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.")
    ]

    static let userChatMessage = ChatMessage(
        role: .user,
        text: "Move design review to tomorrow at 3 PM."
    )

    static let assistantChatMessage = ChatMessage(
        role: .assistant,
        text: "I found one design review tomorrow afternoon and can move it to 3 PM."
    )

    static let markdownAssistantChatMessage = ChatMessage(
        role: .assistant,
        text: "**Plan:** move Design Review to 3 PM, then refresh the week calendar."
    )

    static let activeChatMessages: [ChatMessage] = [
        emptyChatMessages[0],
        ChatMessage(role: .user, text: "What's on my calendar today?"),
        ChatMessage(role: .assistant, text: "Team Standup is now. Lunch with Sarah is at 1 PM."),
        userChatMessage,
        assistantChatMessage,
    ]

    static let sendingChatMessages: [ChatMessage] = activeChatMessages + [
        ChatMessage(role: .user, text: "Add a short focus block after lunch.")
    ]

    static let longChatMessages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule."),
        ChatMessage(role: .user, text: "What does my week look like?"),
        ChatMessage(role: .assistant, text: "You have a busy week. Monday has school time in the morning and a Focus Planning block at 9:45 AM. Tuesday is packed with a Design Sync at 9:45, a Sync at 11, and a Tech Huddle at 1 PM. Wednesday is meeting-free — just recurring focus time. Thursday has a Product Review at 10, Support Rotation Handoff at 11:30, and a COP Incident Review at 1. Friday has Oncall Primary at 11 and two clashing events at 3 PM."),
        ChatMessage(role: .user, text: "What's clashing on Friday?"),
        ChatMessage(role: .assistant, text: "At 3 PM on Friday you have two overlapping events: Catchup — Design Review and Support — Customer Call, both one hour long. Then at 4:15 PM three more events overlap: Focus — Release Plan, Sync: Partner Review, and Personal — Appointment."),
        ChatMessage(role: .user, text: "Can you move the Design Review to 4 PM?"),
        ChatMessage(role: .assistant, text: "Done. I moved Catchup — Design Review to 4:00–5:00 PM on Friday. It no longer clashes with Support — Customer Call at 3 PM, though it now partially overlaps with the 4:15 PM cluster. Want me to adjust those too?"),
        ChatMessage(role: .user, text: "Yes, push the release plan and partner review to Monday afternoon."),
        ChatMessage(role: .assistant, text: "Done. Focus — Release Plan and Sync: Partner Review are both moved to Monday afternoon, starting at 2:00 PM and 3:00 PM respectively. Monday now has more events in the afternoon but the Friday conflict is resolved."),
        ChatMessage(role: .user, text: "Add a 30-minute coffee break on Wednesday at 10 AM."),
        ChatMessage(role: .assistant, text: "Done. I added \"Coffee Break\" on Wednesday from 10:00–10:30 AM on your Work calendar."),
        ChatMessage(role: .user, text: "What time is my lunch with Sarah?"),
        ChatMessage(role: .assistant, text: "Lunch with Sarah is on Friday at 12:15 PM, running for one hour until 1:15 PM on your Personal calendar."),
        ChatMessage(role: .user, text: "Move it to Thursday at 12:30 PM."),
        ChatMessage(role: .assistant, text: "Done. Lunch with Sarah is rescheduled to Thursday at 12:30–1:30 PM. Thursday now has Product Review at 10, Lunch with Sarah at 12:30, Support Rotation at 11:30, and COP Review at 1 PM — note the overlap with the Support and COP events. Want me to shift any of those?"),
        ChatMessage(role: .user, text: "No, that's fine. Can you block Friday afternoon as focus time?"),
        ChatMessage(role: .assistant, text: "Done. I added a 3-hour \"Focus Time\" block on Friday from 1:00–4:00 PM on your Work calendar. That gives you a clear run before the Design Review at 4 PM."),
    ]

    static let shortComposerDraft = "Schedule a 30 minute planning block tomorrow morning."

    static let longComposerDraft = """
    Move the vendor sync out of the afternoon and find the next quiet slot this week.
    Keep lunch and the design review untouched.
    """

    static let voiceInputLevels: [Double] = [
        0.12, 0.22, 0.36, 0.58, 0.32, 0.74, 0.42, 0.27,
        0.63, 0.88, 0.45, 0.19, 0.35, 0.70, 0.52, 0.24,
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

    private static func conversation(
        id: String,
        title: String,
        updatedAt: Date,
        messages: [ChatMessage]
    ) -> ChatConversationRecord {
        ChatConversationRecord(
            id: UUID(uuidString: id)!,
            title: title,
            createdAt: messages.first?.createdAt ?? updatedAt,
            updatedAt: updatedAt,
            messages: messages
        )
    }

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
        messages: [ChatMessage] = PreviewData.conversations.first?.messages ?? PreviewData.messages,
        isSending: Bool = false,
        assistantLoadingState: AssistantLoadingState = .thinking,
        apiKeyStatus: APIKeyStatus = .unknown,
        apiKeyDraft: String = "preview-key"
    ) -> AppModel {
        let conversationStore = PreviewConversationStore()
        let model = AppModel(
            calendarStore: PreviewCalendarStore(status: status, calendars: calendars, events: events),
            memoryStore: MemoryStore(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ical-mac-preview")),
            conversationStore: conversationStore,
            promptStore: PromptStore(),
            apiKeyStore: PreviewAPIKeyStore(key: apiKeyDraft.isEmpty ? nil : apiKeyDraft),
            client: PreviewOpenAIClient()
        )
        model.events = events
        model.calendars = calendars
        model.accessStatus = status
        model.displayedWeekStartDate = PreviewData.visibleWeekStart
        model.statusText = "Synced 9:00 AM"
        model.messages = messages
        model.isSending = isSending
        model.assistantLoadingState = assistantLoadingState
        model.apiKeyDraft = apiKeyDraft
        model.apiKeyStatus = apiKeyStatus
        model.conversationSummaries = PreviewData.conversations
            .map(\.summary)
            .sorted { $0.updatedAt > $1.updatedAt }
        model.selectedConversationID = model.conversationSummaries.first?.id
        return model
    }
}
#endif
