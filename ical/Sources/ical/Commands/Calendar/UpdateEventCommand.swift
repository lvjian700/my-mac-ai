import ArgumentParser
import Foundation

struct UpdateEventCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update an existing calendar event."
  )

  @Argument(help: "Event ID (from `ical events --format json`).")
  var eventId: String

  @Option(name: .long, help: "New title.")
  var title: String?

  @Option(name: .long, help: "New start date/time (ISO-8601 or YYYY-MM-DD).")
  var start: String?

  @Option(name: .long, help: "Absolute end date/time. Overrides duration preservation when combined with --start. Ignored if a duration flag is given.")
  var end: String?

  @Flag(name: .long, help: "Short event: 15 minutes.")
  var short: Bool = false

  @Flag(name: .long, help: "Normal event: 30 minutes.")
  var normal: Bool = false

  @Flag(name: .long, help: "Long event: 45 minutes.")
  var long: Bool = false

  @Option(name: .long, help: "Move event to this calendar.")
  var calendar: String?

  @Option(name: .long, help: "Account name to disambiguate calendars with duplicate names.")
  var account: String?

  @Option(name: .long, help: "Output format: text or json.")
  var format: OutputFormat = .text

  /// Compute the updated end date.
  /// Returns `nil` if no end change is needed.
  func resolveEndDate(effectiveStart: Date, existingStart: Date, existingEnd: Date) throws -> Date? {
    if let date = try resolveFlaggedEndDate(from: effectiveStart, short: short, long: long, normal: normal, endStr: end) {
      return date
    }
    // --start given with no end hint: shift end by same delta to preserve original duration
    if start != nil {
      let delta = effectiveStart.timeIntervalSince(existingStart)
      return existingEnd.addingTimeInterval(delta)
    }
    return nil
  }

  @MainActor
  func run() async throws {
    let svc = EventKitService.shared
    try await svc.requestAccess()

    let existing = try svc.fetchEvent(byId: eventId)

    let hasAnyChange = title != nil || start != nil || end != nil
      || short || normal || long
      || calendar != nil || account != nil
    guard hasAnyChange else {
      fputs("Warning: no update options provided. Event unchanged.\n", stderr)
      OutputFormatter.printEvents([existing], format: format)
      return
    }

    guard let existingStart = existing.startDate as Date?,
          let existingEnd   = existing.endDate   as Date? else {
      throw IcalError.invalidDate(string: "event has nil start or end date")
    }

    let newStart: Date? = try start.map { try DateParser.parse($0) }
    let effectiveStart: Date = newStart ?? existingStart
    let newEnd = try resolveEndDate(
      effectiveStart: effectiveStart,
      existingStart: existingStart,
      existingEnd: existingEnd
    )

    if let end = newEnd, end <= effectiveStart {
      throw IcalError.invalidDate(string: "end date must be after start date")
    }

    let updated = try svc.updateEvent(
      id: eventId,
      title: title,
      startDate: newStart,
      endDate: newEnd,
      calendarName: calendar,
      account: account
    )
    OutputFormatter.printEvents([updated], format: format)
  }
}
