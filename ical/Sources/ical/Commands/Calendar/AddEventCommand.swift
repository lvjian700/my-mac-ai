import ArgumentParser

struct AddEventCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Add an event to a calendar."
  )

  @Argument(help: "Event title.")
  var title: String

  @Option(name: .long, help: "Start date/time (ISO-8601 or YYYY-MM-DD).")
  var start: String

  @Option(name: .long, help: "End date/time (ISO-8601 or YYYY-MM-DD).")
  var end: String

  @Option(name: .long, help: "Calendar name (defaults to default calendar).")
  var calendar: String?

  @Option(name: .long, help: "Account name to disambiguate calendars with duplicate names.")
  var account: String? = nil

  @Option(name: .long, help: "Location.")
  var location: String?

  @Option(name: .long, help: "Notes.")
  var notes: String?

  @Flag(name: .long, help: "All-day event.")
  var allDay: Bool = false

  @Option(name: .long, help: "Output format: text or json.")
  var format: OutputFormat = .text

  @MainActor
  func run() async throws {
    let startDate = try DateParser.parse(start)
    let endDate = try DateParser.parse(end)
    let svc = EventKitService.shared
    try await svc.requestAccess()
    let event = try svc.addEvent(
      title: title,
      startDate: startDate,
      endDate: endDate,
      calendarName: calendar,
      account: account,
      location: location,
      notes: notes,
      allDay: allDay
    )
    OutputFormatter.printEvents([event], format: format)
  }
}
