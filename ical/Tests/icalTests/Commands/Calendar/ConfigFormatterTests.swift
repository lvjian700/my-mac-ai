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
}
