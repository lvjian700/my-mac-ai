import ArgumentParser
import Foundation

struct AddEventCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Add an event to a calendar."
  )

  @Argument(help: "Event title.")
  var title: String

  @Option(name: .long, help: "Start date/time (ISO-8601 or YYYY-MM-DD).")
  var start: String

  @Option(
    name: .long,
    help: "End date/time (ISO-8601 or YYYY-MM-DD). Not needed if a duration flag is used.")
  var end: String?

  @Flag(name: .long, help: "Short event: 15 minutes.")
  var short: Bool = false

  @Flag(name: .long, help: "Normal event: 30 minutes.")
  var normal: Bool = false

  @Flag(name: .long, help: "Long event: 45 minutes.")
  var long: Bool = false

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

  func resolveEndDate(from startDate: Date) throws -> Date {
    if short { return startDate.addingTimeInterval(15 * 60) }
    if long  { return startDate.addingTimeInterval(45 * 60) }
    if let endStr = end { return try DateParser.parse(endStr) }
    return startDate.addingTimeInterval(30 * 60)
  }

  @MainActor
  func run() async throws {
    let startDate = try DateParser.parse(start)
    let endDate = try resolveEndDate(from: startDate)
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
