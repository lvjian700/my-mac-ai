import Foundation
import ICalMacCore

@MainActor
public final class AppModel: ObservableObject {
    @Published public var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.")
    ]
    @Published public var events: [CalendarEvent] = []
    @Published public var calendars: [CalendarInfo] = []
    @Published public var accessStatus: CalendarAccessStatus = .notDetermined
    @Published public var statusText = "Calendar not loaded"
    @Published public var isSending = false
    @Published public var isRefreshing = false
    @Published public var apiKeyDraft = ""
    @Published public var modelName = UserDefaults.standard.string(forKey: "icalMac.model") ?? "gpt-4.5-mini"
    @Published public var defaultCalendarTitle = UserDefaults.standard.string(forKey: "icalMac.defaultCalendarTitle") ?? ""
    @Published public var isShowingCachedSnapshot = false
    @Published public var selectedCalendarIDs: Set<String> = []
    @Published public var displayedWeekStartDate = AppModel.startOfWeek(containing: Date())

    private let calendarStore: CalendarStore
    private let memoryStore: MemoryStore
    private let promptStore: PromptStore
    private let apiKeyStore: APIKeyStore
    private let client: OpenAIClient
    private var assistant: AssistantService
    private var snapshot: SessionSnapshot?
    private var pollingTask: Task<Void, Never>?
    private var hasInitializedCalendarSelection = false

    public init(
        calendarStore: CalendarStore = EventKitCalendarStore(),
        memoryStore: MemoryStore = MemoryStore(),
        promptStore: PromptStore = PromptStore(),
        apiKeyStore: APIKeyStore = OpenAIAPIKeyStore(),
        client: OpenAIClient = URLSessionOpenAIClient()
    ) {
        self.calendarStore = calendarStore
        self.memoryStore = memoryStore
        self.promptStore = promptStore
        self.apiKeyStore = apiKeyStore
        self.client = client
        self.assistant = AssistantService(
            client: client,
            apiKeyStore: apiKeyStore,
            memoryStore: memoryStore,
            promptStore: promptStore,
            toolExecutor: CalendarToolExecutor(
                calendarStore: calendarStore,
                memoryStore: memoryStore,
                defaultCalendarTitle: UserDefaults.standard.string(forKey: "icalMac.defaultCalendarTitle")
            ),
            configuration: AssistantConfiguration(model: UserDefaults.standard.string(forKey: "icalMac.model") ?? "gpt-4.5-mini")
        )
        self.snapshot = memoryStore.readSnapshot()
        self.events = snapshot?.events ?? []
        self.isShowingCachedSnapshot = snapshot != nil
        self.accessStatus = calendarStore.accessStatus()
    }

    public var isUsingEnvAPIKey: Bool {
        !(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "").isEmpty
    }

    public var hasAPIKey: Bool {
        isUsingEnvAPIKey || !(apiKeyStore.readAPIKey() ?? "").isEmpty
    }

    public func loadAPIKeyDraft() {
        guard !isUsingEnvAPIKey else { return }
        apiKeyDraft = apiKeyStore.readAPIKey() ?? ""
    }

    public var displayedWeekRange: CalendarQuery {
        Self.weekRange(containing: displayedWeekStartDate)
    }

    public var visibleEvents: [CalendarEvent] {
        events.filter { event in
            event.intersects(displayedWeekRange)
                && (!hasInitializedCalendarSelection || event.calendarIdentifier.map(selectedCalendarIDs.contains) == true)
        }
    }

    public var visibleAllDayEvents: [CalendarEvent] {
        visibleEvents.filter(\.isAllDay)
    }

    public var visibleTimedEvents: [CalendarEvent] {
        visibleEvents.filter { !$0.isAllDay }
    }

    public var displayedWeekEndDate: Date {
        displayedWeekRange.endDate
    }

    public func loadCalendarOnLaunch() async {
        accessStatus = calendarStore.accessStatus()
        await refreshCalendar()
    }

    public func refreshCalendar() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            accessStatus = calendarStore.accessStatus()
            if accessStatus != .granted {
                try await calendarStore.requestAccess()
                accessStatus = calendarStore.accessStatus()
            }
            calendars = try calendarStore.listCalendars()
            reconcileSelectedCalendars()
            let builder = SessionSnapshotBuilder(calendarStore: calendarStore)
            let nextSnapshot = try builder.snapshot(range: displayedWeekRange)
            try memoryStore.writeSnapshot(nextSnapshot)
            snapshot = nextSnapshot
            events = nextSnapshot.events
            isShowingCachedSnapshot = false
            statusText = "Synced \(Self.timeFormatter.string(from: nextSnapshot.syncedAt))"
        } catch {
            statusText = error.localizedDescription
            accessStatus = calendarStore.accessStatus()
        }
    }

    public func startAutoRefresh(interval: Duration = .seconds(60)) {
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                await self?.refreshCalendar()
            }
        }
    }

    public func stopAutoRefresh() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func showToday() async {
        displayedWeekStartDate = Self.startOfWeek(containing: Date())
        await refreshCalendar()
    }

    public func moveDisplayedWeek(by value: Int) async {
        displayedWeekStartDate = Calendar.current.date(byAdding: .day, value: value * 7, to: displayedWeekStartDate) ?? displayedWeekStartDate
        await refreshCalendar()
    }

    public func setCalendar(id: String, isSelected: Bool) {
        if isSelected {
            selectedCalendarIDs.insert(id)
        } else {
            selectedCalendarIDs.remove(id)
        }
    }

    public func colorHex(for event: CalendarEvent) -> String? {
        guard let calendarIdentifier = event.calendarIdentifier else { return nil }
        return calendars.first(where: { $0.id == calendarIdentifier })?.colorHex
    }

    public func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isSending = true
        defer { isSending = false }

        do {
            let reply = try await assistant.send(trimmed, snapshot: filteredSnapshotForAssistant())
            messages.append(ChatMessage(role: .assistant, text: reply))
            await refreshCalendar()
        } catch {
            messages.append(ChatMessage(role: .assistant, text: error.localizedDescription))
        }
    }

    public func saveSettings() {
        UserDefaults.standard.set(modelName, forKey: "icalMac.model")
        let defaultCalendar = defaultCalendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if defaultCalendar.isEmpty {
            UserDefaults.standard.removeObject(forKey: "icalMac.defaultCalendarTitle")
        } else {
            UserDefaults.standard.set(defaultCalendar, forKey: "icalMac.defaultCalendarTitle")
        }
        if !isUsingEnvAPIKey {
            do {
                let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty {
                    try apiKeyStore.deleteAPIKey()
                } else {
                    try apiKeyStore.writeAPIKey(key)
                }
            } catch {
                statusText = error.localizedDescription
                return
            }
        }
        rebuildAssistant()
        statusText = "Settings saved"
    }

    public func clearChat() {
        assistant.clearHistory()
        messages = [ChatMessage(role: .assistant, text: "Fresh thread. What should we do with your calendar?")]
    }

    public static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.component(.weekday, from: date)
        let daysFromMonday = day == 1 ? 6 : day - 2
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    public static func weekRange(containing date: Date, calendar: Calendar = .current) -> CalendarQuery {
        let start = startOfWeek(containing: date, calendar: calendar)
        let endOfLastDay = calendar.date(byAdding: DateComponents(day: 7, second: -1), to: start) ?? start
        return CalendarQuery(startDate: start, endDate: endOfLastDay)
    }

    private func rebuildAssistant() {
        assistant = AssistantService(
            client: client,
            apiKeyStore: apiKeyStore,
            memoryStore: memoryStore,
            promptStore: promptStore,
            toolExecutor: CalendarToolExecutor(
                calendarStore: calendarStore,
                memoryStore: memoryStore,
                defaultCalendarTitle: defaultCalendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            configuration: AssistantConfiguration(model: modelName)
        )
    }

    private func reconcileSelectedCalendars() {
        let ids = Set(calendars.map(\.id))
        if !hasInitializedCalendarSelection {
            selectedCalendarIDs = ids
            hasInitializedCalendarSelection = true
            return
        }
        selectedCalendarIDs = selectedCalendarIDs.intersection(ids)
    }

    private func filteredSnapshotForAssistant() -> SessionSnapshot? {
        guard let snapshot else { return nil }
        return SessionSnapshot(
            events: visibleEvents,
            syncedAt: snapshot.syncedAt,
            range: displayedWeekRange
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension CalendarEvent {
    func intersects(_ range: CalendarQuery) -> Bool {
        startDate < range.endDate && endDate > range.startDate
    }
}
