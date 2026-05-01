import ArgumentParser
import Foundation

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View and update ical configuration.",
        subcommands: [ConfigAddCommand.self]
    )

    @Option(name: .long, help: "Output format: text or json.")
    var format: OutputFormat = .text

    func run() async throws {
        OutputFormatter.printConfig(try ConfigStore().snapshot(), format: format)
    }
}

struct ConfigAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Set defaults used by `ical add`."
    )

    @Option(name: .long, help: "Default account name for new events.")
    var account: String?

    @Option(name: .long, help: "Default calendar name for new events.")
    var calendar: String?

    @Flag(name: .long, help: "Write user-level config at ~/.my-mac-ai/ical/config.json. Defaults to local config at ./.ical/config.json.")
    var user: Bool = false

    @Option(name: .long, help: "Output format: text or json.")
    var format: OutputFormat = .text

    var targetLevel: ConfigLevel {
        user ? .user : .local
    }

    var hasConfigValues: Bool {
        account != nil || calendar != nil
    }

    func run() async throws {
        let store = ConfigStore()
        guard hasConfigValues else {
            OutputFormatter.printAddConfig(try store.snapshot(), format: format)
            return
        }
        _ = try store.writeAddConfig(
            AddCommandConfig(account: account, calendar: calendar),
            level: targetLevel
        )
        OutputFormatter.printConfig(try store.snapshot(), format: format)
    }
}
