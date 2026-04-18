import ArgumentParser

struct ListCalendarsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all calendars."
    )

    @Option(name: .long, help: "Output format: text or json.")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Filter by account name (e.g. iCloud, \"On My Mac\").")
    var account: String? = nil

    @MainActor
    func run() async throws {
        let svc = EventKitService.shared
        try await svc.requestAccess()
        let groups = try svc.listCalendarsGrouped(account: account)
        OutputFormatter.printCalendarsGrouped(groups, format: format)
    }
}
