import Foundation

enum ConfigError: LocalizedError {
    case noConfigValues

    var errorDescription: String? {
        switch self {
        case .noConfigValues:
            return "Provide at least one config value."
        }
    }
}

enum ConfigLevel: String, Codable {
    case user
    case local
    case effective
}

struct AddCommandConfig: Codable, Equatable {
    var account: String?
    var calendar: String?

    var isEmpty: Bool {
        account == nil && calendar == nil
    }

    func merged(over base: AddCommandConfig) -> AddCommandConfig {
        AddCommandConfig(
            account: account ?? base.account,
            calendar: calendar ?? base.calendar
        )
    }
}

struct IcalConfigFile: Codable, Equatable {
    var add: AddCommandConfig = AddCommandConfig()
}

struct IcalConfigSnapshot: Equatable {
    let userPath: URL
    let user: IcalConfigFile
    let localPath: URL?
    let local: IcalConfigFile

    var effectiveAdd: AddCommandConfig {
        local.add.merged(over: user.add)
    }
}

struct ConfigStore {
    let userConfigURL: URL
    let workingDirectory: URL
    let fileManager: FileManager

    init(
        userConfigURL: URL? = nil,
        workingDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.workingDirectory = workingDirectory ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        self.userConfigURL = userConfigURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".my-mac-ai", isDirectory: true)
                .appendingPathComponent("ical", isDirectory: true)
                .appendingPathComponent("config.json")
    }

    func snapshot() throws -> IcalConfigSnapshot {
        let localURL = nearestLocalConfigURL()
        return IcalConfigSnapshot(
            userPath: userConfigURL,
            user: try readConfig(at: userConfigURL),
            localPath: localURL,
            local: try localURL.map { try readConfig(at: $0) } ?? IcalConfigFile()
        )
    }

    func effectiveAddConfig() throws -> AddCommandConfig {
        try snapshot().effectiveAdd
    }

    func writeAddConfig(_ addConfig: AddCommandConfig, level: ConfigLevel) throws -> URL {
        guard !addConfig.isEmpty else {
            throw ConfigError.noConfigValues
        }
        let url: URL
        switch level {
        case .user:
            url = userConfigURL
        case .local:
            url = localConfigURL(forWritingIn: workingDirectory)
        case .effective:
            preconditionFailure("Cannot write effective config.")
        }
        var config = try readConfig(at: url)
        config.add = addConfig.merged(over: config.add)
        try writeConfig(config, to: url)
        return url
    }

    func localConfigURL(forWritingIn directory: URL) -> URL {
        directory
            .standardizedFileURL
            .appendingPathComponent(".ical", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    func nearestLocalConfigURL() -> URL? {
        var directory = workingDirectory.standardizedFileURL
        while true {
            let candidate = localConfigURL(forWritingIn: directory)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path {
                return nil
            }
            directory = parent
        }
    }

    private func readConfig(at url: URL) throws -> IcalConfigFile {
        guard fileManager.fileExists(atPath: url.path) else {
            return IcalConfigFile()
        }
        let data = try Data(contentsOf: url)
        if data.isEmpty {
            return IcalConfigFile()
        }
        return try JSONDecoder().decode(IcalConfigFile.self, from: data)
    }

    private func writeConfig(_ config: IcalConfigFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
