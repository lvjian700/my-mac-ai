import ArgumentParser

struct ListCalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all calendars."
    )

    @Option(name: .long, help: "Output format: text or json.")
    var format: OutputFormat = .text

    func run() async throws {
        let svc = EventKitService.shared
        try await svc.requestEventsAccess()
        let calendars = svc.listCalendars(for: .event)
        OutputFormatter.printCalendars(calendars, format: format)
    }
}
