import ArgumentParser

@main
struct IcalCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ical",
    abstract: "Apple Calendar from the command line.",
    version: "0.1.0",
    subcommands: [ListCalendarsCommand.self, ListEventsCommand.self, AddEventCommand.self, UpdateEventCommand.self],
    defaultSubcommand: ListEventsCommand.self
  )
}
