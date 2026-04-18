import ArgumentParser

struct ListEventsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "events",
        abstract: "List calendar events."
    )

    @Option(name: .long, help: "Output format: text or json.")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Start date (today, tomorrow, YYYY-MM-DD, or ISO-8601).")
    var from: String = "today"

    @Option(name: .long, help: "End date (today, tomorrow, YYYY-MM-DD, or ISO-8601).")
    var to: String = "tomorrow"

    @Option(name: .long, help: "Filter by calendar name (repeatable).")
    var calendar: [String] = []

    @Option(name: .long, help: "Filter by account name.")
    var account: String? = nil

    @MainActor
    func run() async throws {
        let startDate = try DateParser.parse(from)
        let endDate = try DateParser.parse(to)
        let svc = EventKitService.shared
        try await svc.requestAccess()
        let events = try svc.listEvents(from: startDate, to: endDate, calendars: calendar, account: account)
        OutputFormatter.printEvents(events, format: format)
    }
}
