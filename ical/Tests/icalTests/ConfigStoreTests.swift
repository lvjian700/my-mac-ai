import Foundation
import Testing
@testable import ical

struct ConfigStoreTests {
    private func makeTempDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ical-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func userConfigPathStoresAddDefaults() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let userURL = root.appendingPathComponent("user/config.json")
        let store = ConfigStore(userConfigURL: userURL, workingDirectory: root)

        let writtenURL = try store.writeAddConfig(
            AddCommandConfig(account: "iCloud", calendar: "Home"),
            level: .user
        )

        #expect(writtenURL == userURL)
        let snapshot = try store.snapshot()
        #expect(snapshot.user.add.account == "iCloud")
        #expect(snapshot.user.add.calendar == "Home")
        #expect(snapshot.effectiveAdd.account == "iCloud")
        #expect(snapshot.effectiveAdd.calendar == "Home")
    }

    @Test func defaultUserConfigPathUsesMyMacAIDirectory() throws {
        let store = ConfigStore()

        #expect(store.userConfigURL.path.hasSuffix("/.my-mac-ai/ical/config.json"))
    }

    @Test func localConfigOverridesUserConfigByNearestAncestor() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("project", isDirectory: true)
        let child = project.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

        let userURL = root.appendingPathComponent("user/config.json")
        let userStore = ConfigStore(userConfigURL: userURL, workingDirectory: root)
        _ = try userStore.writeAddConfig(
            AddCommandConfig(account: "iCloud", calendar: "Personal"),
            level: .user
        )

        let localStore = ConfigStore(userConfigURL: userURL, workingDirectory: project)
        _ = try localStore.writeAddConfig(
            AddCommandConfig(account: nil, calendar: "Work"),
            level: .local
        )

        let nestedStore = ConfigStore(userConfigURL: userURL, workingDirectory: child)
        let snapshot = try nestedStore.snapshot()

        #expect(snapshot.localPath == project.appendingPathComponent(".ical/config.json"))
        #expect(snapshot.effectiveAdd.account == "iCloud")
        #expect(snapshot.effectiveAdd.calendar == "Work")
    }

    @Test func addCommandExplicitOptionsOverrideConfig() throws {
        var command = try AddEventCommand.parse([
            "Meeting",
            "--start", "2026-04-24T10:00:00",
            "--account", "Explicit",
        ])
        command.calendar = nil

        let resolved = command.resolvedAddConfig(
            from: AddCommandConfig(account: "ConfigAccount", calendar: "ConfigCalendar")
        )

        #expect(resolved.account == "Explicit")
        #expect(resolved.calendar == "ConfigCalendar")
    }

    @Test func configAddCommandDefaultsToLocalLevel() throws {
        let command = try ConfigAddCommand.parse([
            "--account", "iCloud",
            "--calendar", "Work",
        ])

        #expect(command.targetLevel == .local)
    }

    @Test func configAddCommandWithoutValuesIsReadOnly() throws {
        let command = try ConfigAddCommand.parse([])

        #expect(command.hasConfigValues == false)
    }

    @Test func configAddCommandWithOneValueWritesConfig() throws {
        let command = try ConfigAddCommand.parse([
            "--calendar", "Work",
        ])

        #expect(command.hasConfigValues)
    }

    @Test func configAddCommandUserFlagTargetsUserLevel() throws {
        let command = try ConfigAddCommand.parse([
            "--user",
            "--account", "iCloud",
            "--calendar", "Work",
        ])

        #expect(command.targetLevel == .user)
    }
}
