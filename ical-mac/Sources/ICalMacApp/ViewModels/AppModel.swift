import Foundation
import ICalMacCore

@MainActor
final class AppModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Ask about your calendar or tell me what to schedule.")
    ]
    @Published var events: [CalendarEvent] = []
    @Published var calendars: [CalendarInfo] = []
    @Published var accessStatus: CalendarAccessStatus = .notDetermined
    @Published var statusText = "Calendar not loaded"
    @Published var isSending = false
    @Published var isRefreshing = false
    @Published var apiKeyDraft = ""
    @Published var modelName = UserDefaults.standard.string(forKey: "icalMac.model") ?? "claude-sonnet-4-6"
    @Published var defaultCalendarTitle = UserDefaults.standard.string(forKey: "icalMac.defaultCalendarTitle") ?? ""

    private let calendarStore: CalendarStore
    private let memoryStore: MemoryStore
    private let promptStore: PromptStore
    private let apiKeyStore: APIKeyStore
    private let client: AnthropicClient
    private var assistant: AssistantService
    private var snapshot: SessionSnapshot?

    init(
        calendarStore: CalendarStore = EventKitCalendarStore(),
        memoryStore: MemoryStore = MemoryStore(),
        promptStore: PromptStore = PromptStore(),
        apiKeyStore: APIKeyStore = AnthropicAPIKeyStore(),
        client: AnthropicClient = URLSessionAnthropicClient()
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
            configuration: AssistantConfiguration(model: UserDefaults.standard.string(forKey: "icalMac.model") ?? "claude-sonnet-4-6")
        )
        self.apiKeyDraft = apiKeyStore.readAPIKey() ?? ""
        self.snapshot = memoryStore.readSnapshot()
        self.events = snapshot?.events ?? []
        self.accessStatus = calendarStore.accessStatus()
    }

    var hasAPIKey: Bool {
        !(apiKeyStore.readAPIKey() ?? "").isEmpty
    }

    func loadCalendarOnLaunch() async {
        accessStatus = calendarStore.accessStatus()
        guard accessStatus == .granted else {
            statusText = "Calendar permission not requested"
            return
        }
        await refreshCalendar()
    }

    func refreshCalendar() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            accessStatus = calendarStore.accessStatus()
            if accessStatus != .granted {
                try await calendarStore.requestAccess()
                accessStatus = calendarStore.accessStatus()
            }
            calendars = try calendarStore.listCalendars()
            let builder = SessionSnapshotBuilder(calendarStore: calendarStore)
            let nextSnapshot = try builder.currentTwoWeekSnapshot()
            try memoryStore.writeSnapshot(nextSnapshot)
            snapshot = nextSnapshot
            events = nextSnapshot.events
            statusText = "Synced \(Self.timeFormatter.string(from: nextSnapshot.syncedAt))"
        } catch {
            statusText = error.localizedDescription
            accessStatus = calendarStore.accessStatus()
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isSending = true
        defer { isSending = false }

        do {
            let reply = try await assistant.send(trimmed, snapshot: snapshot)
            messages.append(ChatMessage(role: .assistant, text: reply))
            await refreshCalendar()
        } catch {
            messages.append(ChatMessage(role: .assistant, text: error.localizedDescription))
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(modelName, forKey: "icalMac.model")
        let defaultCalendar = defaultCalendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if defaultCalendar.isEmpty {
            UserDefaults.standard.removeObject(forKey: "icalMac.defaultCalendarTitle")
        } else {
            UserDefaults.standard.set(defaultCalendar, forKey: "icalMac.defaultCalendarTitle")
        }
        do {
            let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty {
                try apiKeyStore.deleteAPIKey()
            } else {
                try apiKeyStore.writeAPIKey(key)
            }
            rebuildAssistant()
            statusText = "Settings saved"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func clearChat() {
        assistant.clearHistory()
        messages = [ChatMessage(role: .assistant, text: "Fresh thread. What should we do with your calendar?")]
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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
