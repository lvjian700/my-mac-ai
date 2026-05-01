import Testing
import Foundation
@testable import ical

@MainActor
struct ConfigFormatterTests {

    @Test func configTextOutputAbbreviatesUserHomePath() {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(add: AddCommandConfig(account: "iCloud", calendar: "Work")),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .text)
        }

        #expect(output.contains("user: ~/.my-mac-ai/ical/config.json"),
                "Expected abbreviated user path in:\n\(output)")
    }

    @Test func configText_unsetValues_displayedAsUnset() {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(add: AddCommandConfig(account: nil, calendar: nil)),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .text)
        }

        #expect(output.contains("(unset)"),
                "Expected '(unset)' for nil account and calendar in:\n\(output)")
    }

    @Test func configText_withoutLocalConfigFile_showsNotConfigured() {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .text)
        }

        #expect(output.contains("local: not configured"),
                "Expected 'local: not configured' when localPath is nil in:\n\(output)")
    }

    @Test func configText_alwaysShowsEffectiveSection() {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(add: AddCommandConfig(account: "iCloud", calendar: nil)),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .text)
        }

        #expect(output.contains("effective:"),
                "Expected 'effective:' section in config text output in:\n\(output)")
    }

    @Test func configJSON_containsUserLocalAndEffectiveSections() throws {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(add: AddCommandConfig(account: "iCloud", calendar: "Work")),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .json)
        }

        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(parsed != nil, "Expected valid JSON object")
        #expect(parsed?["user"] != nil,      "Expected 'user' key in config JSON")
        #expect(parsed?["local"] != nil,     "Expected 'local' key in config JSON")
        #expect(parsed?["effective"] != nil, "Expected 'effective' key in config JSON")
    }

    @Test func configJSON_userSection_includesConfiguredAccountAndCalendar() throws {
        let userPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mac-ai/ical/config.json")
        let snapshot = IcalConfigSnapshot(
            userPath: userPath,
            user: IcalConfigFile(add: AddCommandConfig(account: "iCloud", calendar: "Work")),
            localPath: nil,
            local: IcalConfigFile()
        )

        let output = captureStdout {
            OutputFormatter.printConfig(snapshot, format: .json)
        }

        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let user = parsed?["user"] as? [String: Any]
        let add  = user?["add"] as? [String: Any]

        #expect(add?["account"] as? String == "iCloud",
                "Expected account 'iCloud' in user.add, got \(String(describing: add?["account"]))")
        #expect(add?["calendar"] as? String == "Work",
                "Expected calendar 'Work' in user.add, got \(String(describing: add?["calendar"]))")
    }
}
