import Foundation
import ICalMacCore
import Testing
@testable import ICalMacUI

@MainActor
struct AppModelTests {
    @Test func weekRangeStartsOnMondayAndEndsOnSunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = makeDate(year: 2026, month: 5, day: 20, hour: 15)

        let range = AppModel.weekRange(containing: date, calendar: calendar)

        #expect(range.startDate == makeDate(year: 2026, month: 5, day: 18))
        #expect(range.endDate == makeDate(year: 2026, month: 5, day: 24, hour: 23, minute: 59, second: 59))
    }

    @Test func selectedCalendarsFilterVisibleEventsByIdentifier() async throws {
        let store = FakeUICalendarStore()
        store.calendars = [
            CalendarInfo(id: "work", title: "Work", accountName: "iCloud", allowsContentModifications: true, colorHex: "#007AFF"),
            CalendarInfo(id: "home", title: "Home", accountName: "iCloud", allowsContentModifications: true, colorHex: "#34C759"),
        ]
        store.events = [
            event(id: "standup", title: "Standup", calendarID: "work"),
            event(id: "dinner", title: "Dinner", calendarID: "home"),
        ]
        let model = try makeModel(store: store)
        model.displayedWeekStartDate = makeDate(year: 2026, month: 5, day: 18)

        await model.refreshCalendar()
        model.setCalendar(id: "work", isSelected: false)

        #expect(model.visibleEvents.map(\.id) == ["dinner"])
        #expect(model.colorHex(for: store.events[1]) == "#34C759")
    }

    @Test func launchRequestsCalendarAccessAndLoadsEvents() async throws {
        let store = FakeUICalendarStore()
        store.status = .notDetermined
        store.calendars = [
            CalendarInfo(id: "work", title: "Work", accountName: "iCloud", allowsContentModifications: true)
        ]
        store.events = [event(id: "standup", title: "Standup", calendarID: "work")]
        let model = try makeModel(store: store)
        model.displayedWeekStartDate = makeDate(year: 2026, month: 5, day: 18)

        await model.loadCalendarOnLaunch()

        #expect(store.requestAccessCount == 1)
        #expect(model.accessStatus == .granted)
        #expect(model.calendars.map(\.id) == ["work"])
        #expect(model.visibleEvents.map(\.id) == ["standup"])
        #expect(model.isShowingCachedSnapshot == false)
    }

    @Test func refreshSkipsOverlappingRequests() async throws {
        let store = FakeUICalendarStore()
        store.status = .notDetermined
        store.accessDelay = .milliseconds(50)
        let model = try makeModel(store: store)

        let first = Task { await model.refreshCalendar() }
        await Task.yield()
        let second = Task { await model.refreshCalendar() }

        await first.value
        await second.value

        #expect(store.listEventsCount == 1)
    }

    @Test func initDoesNotReadAPIKeyUntilDraftLoads() throws {
        let store = FakeUICalendarStore()
        let keyStore = FakeUIAPIKeyStore(key: "test-key")
        let model = try makeModel(store: store, apiKeyStore: keyStore)

        #expect(keyStore.readCount == 0)
        #expect(model.apiKeyDraft == "")

        model.loadAPIKeyDraft()

        #expect(keyStore.readCount == 1)
        #expect(model.apiKeyDraft == "test-key")
    }

    @Test func sendingMessageRefreshesCalendarAfterAssistantReply() async throws {
        let store = FakeUICalendarStore()
        store.calendars = [
            CalendarInfo(id: "work", title: "Work", accountName: "iCloud", allowsContentModifications: true)
        ]
        store.events = [event(id: "standup", title: "Standup", calendarID: "work")]
        let model = try makeModel(
            store: store,
            client: FakeUIOpenAIClient(responses: [
                OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "Done")])])
            ])
        )
        model.displayedWeekStartDate = makeDate(year: 2026, month: 5, day: 18)

        await model.refreshCalendar()
        await model.send("Move standup")

        #expect(store.listEventsCount == 2)
        #expect(model.messages.last?.text == "Done")
    }

    @Test func refreshLogsNewInvitationsOnce() async throws {
        let store = FakeUICalendarStore()
        store.calendars = [
            CalendarInfo(id: "work", title: "Work", accountName: "iCloud", allowsContentModifications: true)
        ]
        store.events = [
            event(id: "invite-1", title: "Roadmap Review", calendarID: "work", invitationStatus: .pending)
        ]
        var loggedEventIDs: [String] = []
        let model = try makeModel(store: store, invitationLogger: { event in
            loggedEventIDs.append(event.id)
        })
        model.displayedWeekStartDate = makeDate(year: 2026, month: 5, day: 18)

        await model.refreshCalendar()
        await model.refreshCalendar()
        store.events.append(event(id: "invite-2", title: "Design Crit", calendarID: "work", invitationStatus: .tentative))
        await model.refreshCalendar()

        #expect(loggedEventIDs == ["invite-1", "invite-2"])
    }

    @Test func previewModelRefreshShowsRecurringEventsInVisibleWeek() async throws {
        let model = AppModel.preview()

        await model.refreshCalendar()

        let visibleRecurringEventIDs = Set(model.visibleEvents.filter(\.isRecurring).map(\.id))
        #expect(visibleRecurringEventIDs.contains("recurring-school-time-0"))
        #expect(visibleRecurringEventIDs.contains("recurring-school-pickup-tue-fri-1"))
        #expect(visibleRecurringEventIDs.contains("recurring-school-pickup-monday"))
        #expect(visibleRecurringEventIDs.contains("recurring-focus-meeting-free-day"))
        #expect(visibleRecurringEventIDs.contains("recurring-meet-free-wednesday"))
    }

    @Test func previewTimedEventsIncludeTwoAndThreeEventClashSamples() async throws {
        let model = AppModel.preview()

        await model.refreshCalendar()

        let eventsByID = Dictionary(uniqueKeysWithValues: model.visibleTimedEvents.map { ($0.id, $0) })
        let twoClashEvents = [
            eventsByID["clash-two-design-review"],
            eventsByID["clash-two-customer-call"],
        ].compactMap(\.self)
        let threeClashEvents = [
            eventsByID["clash-three-release-plan"],
            eventsByID["clash-three-partner-sync"],
            eventsByID["clash-three-personal-appointment"],
        ].compactMap(\.self)

        #expect(twoClashEvents.count == 2)
        #expect(threeClashEvents.count == 3)
        #expect(eventsFullyOverlap(twoClashEvents))
        #expect(eventsFullyOverlap(threeClashEvents))
    }

    @Test func weekOccurrenceIDsDifferentiateRecurringOccurrencesWithSharedEventID() {
        let mondayOccurrence = CalendarEvent(
            id: "eventkit-recurring-id",
            title: "Out of office - pickup",
            startDate: makeDate(year: 2026, month: 5, day: 18, hour: 8),
            endDate: makeDate(year: 2026, month: 5, day: 18, hour: 9),
            isAllDay: false,
            isRecurring: true,
            calendarTitle: "Work"
        )
        let tuesdayOccurrence = CalendarEvent(
            id: "eventkit-recurring-id",
            title: "Out of office - pickup",
            startDate: makeDate(year: 2026, month: 5, day: 19, hour: 8),
            endDate: makeDate(year: 2026, month: 5, day: 19, hour: 9),
            isAllDay: false,
            isRecurring: true,
            calendarTitle: "Work"
        )

        #expect(mondayOccurrence.id == tuesdayOccurrence.id)
        #expect(mondayOccurrence.weekOccurrenceID != tuesdayOccurrence.weekOccurrenceID)
    }

    private func makeModel(
        store: FakeUICalendarStore,
        apiKeyStore: APIKeyStore = FakeUIAPIKeyStore(key: "test-key"),
        client: FakeUIOpenAIClient = FakeUIOpenAIClient(responses: [
            OpenAIResponse(output: [.message(role: "assistant", content: [.init(type: "output_text", text: "OK")])])
        ]),
        invitationLogger: @escaping @MainActor (CalendarEvent) -> Void = { _ in }
    ) throws -> AppModel {
        AppModel(
            calendarStore: store,
            memoryStore: MemoryStore(rootURL: try makeTempDirectory()),
            promptStore: PromptStore(),
            apiKeyStore: apiKeyStore,
            client: client,
            invitationLogger: invitationLogger
        )
    }

    private func event(
        id: String,
        title: String,
        calendarID: String,
        invitationStatus: CalendarParticipantStatus? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: makeDate(year: 2026, month: 5, day: 18, hour: 10),
            endDate: makeDate(year: 2026, month: 5, day: 18, hour: 11),
            isAllDay: false,
            calendarTitle: calendarID.capitalized,
            calendarIdentifier: calendarID,
            invitation: invitationStatus.map {
                CalendarInvitationInfo(
                    currentUserStatus: $0,
                    organizerName: "Alice",
                    currentUserName: "Me",
                    attendeeCount: 3
                )
            }
        )
    }
}

@MainActor
private final class FakeUICalendarStore: CalendarStore {
    var status: CalendarAccessStatus = .granted
    var calendars: [CalendarInfo] = []
    var events: [CalendarEvent] = []
    var accessDelay: Duration?
    var requestAccessCount = 0
    var listEventsCount = 0

    func accessStatus() -> CalendarAccessStatus {
        status
    }

    func requestAccess() async throws {
        requestAccessCount += 1
        if let accessDelay {
            try await Task.sleep(for: accessDelay)
        }
        status = .granted
    }

    func listCalendars() async throws -> [CalendarInfo] {
        calendars
    }

    func listEvents(range: CalendarQuery) async throws -> [CalendarEvent] {
        listEventsCount += 1
        return events
    }

    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        throw CalendarStoreError.noWritableCalendar
    }

    func updateEvent(_ update: EventUpdate) async throws -> CalendarEvent {
        throw CalendarStoreError.eventNotFound(update.id)
    }

    func respondToInvitation(id: String, response: CalendarInvitationResponse) async throws -> CalendarEvent {
        guard let event = events.first(where: { $0.id == id }) else {
            throw CalendarStoreError.eventNotFound(id)
        }
        return event
    }
}

private final class FakeUIAPIKeyStore: APIKeyStore, @unchecked Sendable {
    var key: String?
    var readCount = 0

    init(key: String?) {
        self.key = key
    }

    func readAPIKey() -> String? {
        readCount += 1
        return key
    }

    func writeAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
}

private final class FakeUIOpenAIClient: OpenAIClient, @unchecked Sendable {
    private var responses: [OpenAIResponse]

    init(responses: [OpenAIResponse]) {
        self.responses = responses
    }

    func createResponse(_ request: OpenAIRequest, apiKey: String) async throws -> OpenAIResponse {
        responses.removeFirst()
    }
}

private func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("ical-mac-ui-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date!
}

private func eventsFullyOverlap(_ events: [CalendarEvent]) -> Bool {
    guard let first = events.first else { return false }
    return events.allSatisfy {
        $0.startDate == first.startDate && $0.endDate == first.endDate
    }
}
